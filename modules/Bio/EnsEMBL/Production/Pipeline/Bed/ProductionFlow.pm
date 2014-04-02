=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::ProductionFlow

=head1 DESCRIPTION

Provides a number of output flows dependeing on if we find various updates 
in the production database.

=over 8

=item B<1> - Flow to jobs which need to run no-matter what

=item B<2> - Flow to jobs which need to run on assembly updates

=item B<3> - Flow to jobs which need to run on repeat masking updates

=item B<4> - Flow to jobs which need to run on changes in Transcripts

=back

=head1 PARAMS

=over 8

=item B<force_flow> - Force a stage. Supports C<assembly, repeats and genebuild>.

=item B<force> - Force all flows

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::ProductionFlow;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub param_defaults {
  return {
    force => 0,
    force_flow => [],
  };
}

sub fetch_input {
  my ($self) = @_;
  $self->param_required('species');
  my $flow_hash = ($self->param_is_defined('force_flow')) ? { map { $_, 1 } @{$self->param('force_flow')} } : {};
  $self->param('force_flow_lookup', $flow_hash);
  return 1;
}

sub run {
  my ($self) = @_;
  my ($assembly, $repeats, $genebuild) = (0,0,0);
  my $prod_dba = $self->get_production_DBAdaptor();
  if($self->param('force') || ! defined $prod_dba) {
    ($assembly, $repeats, $genebuild) = (1,1,1);
  }
  else {
    #Check the force flow hash. If it's set then force it through
    my $flow_hash = $self->param('force_flow_lookup');
    $assembly   = 1 if $flow_hash->{assembly};
    $repeats    = 1 if $flow_hash->{repeats};
    $genebuild  = 1 if $flow_hash->{genebuild};

    $assembly   = $self->_query_prod($prod_dba, 'assembly')   if ! $assembly;
    $repeats    = $self->_query_prod($prod_dba, 'repeats')    if ! $repeats;
    $genebuild  = $self->_query_prod($prod_dba, 'genebuild')  if ! $genebuild;
  }

  $self->param('assembly', $assembly) if $assembly;
  $self->param('repeats', $repeats) if $repeats;
  $self->param('genebuild', $genebuild) if $genebuild;

  return 1;
}

sub write_output {
  my ($self) = @_;
  my $input_id = {species => $self->param('species')};
  $self->dataflow_output_id($input_id, 1); # always flow to 1
  $self->dataflow_output_id($input_id, 2) if $self->param_is_defined('assembly');
  $self->dataflow_output_id($input_id, 3) if $self->param_is_defined('repeats');
  $self->dataflow_output_id($input_id, 4) if $self->param_is_defined('genebuild');
  return;
}

sub _query_prod {
  my ($self, $prod_dba, $type) = @_;
  my $name = $self->production_name();
  my $base_sql = <<'SQL';
select count(*)
from changelog cl
join changelog_species cls using (changelog_id)
join species s using (species_id)
where s.production_name = ?
and cl.release_id = ?
and cl.status = ?
and
SQL
  my $clause = {
    assembly => ' cl.assembly =?',
    repeats =>  ' cl.repeat_masking =?',
    genebuild => ' cl.gene_set =?',
  }->{$type};

  my $sql = $base_sql.$clause;
  my @bind_params = ($name, $self->param('release'), 'handed_over', 'Y');
  return $prod_dba->dbc->sql_helper()->execute_single_result(-SQL => $sql, -PARAMS => \@bind_params);
}

1;