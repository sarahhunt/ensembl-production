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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed

=head1 DESCRIPTION

Converts a Bed file into a BigBed file ... tadah

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item bed - Path to the bed file we are converting

=item autosql - Path to an AutoSql file of the bed file to index

=item bigbed_indexes - Extra indexes to write

=item bed_type - The type fo bed we are creating e.g. bed6 or bed12+2

=item bed_to_big_bed - Location of the bedToBigBed binary

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub param_defaults {
  return {
    bigbed_indexes => [],
  };
}

sub fetch_input {
  my ($self) = @_;
  $self->SUPER::fetch_input();
  $self->param_required($_) for qw/bed bed_type autosql bigbed_indexes/;
  $self->assert_executable('bed_to_big_bed', 'bedToBigBed');
  return;
}

sub run {
  my ($self) = @_;
  
  my $bed_to_big_bed = $self->param('bed_to_big_bed');
  my $chrom_sizes = $self->chrom_sizes_file();
  my $bed = $self->param('bed');
  my $big_bed = $bed;
  $big_bed =~ s/\.bed$/.bb/;

  my $bed_type = $self->param_required('bed_type');
  my $autosql = $self->param_required('autosql');
  my $indexes = $self->param_required('bigbed_indexes');
  
  my $extra_index = (@{$indexes}) ? '-extraIndex='.join(q{,}, @{$indexes}) : q{};
  my $cmd = sprintf('%s -type=%s -as=%s %s %s %s %s', 
    $bed_to_big_bed, $bed_type, $autosql, $extra_index, $bed, $chrom_sizes, $big_bed);
  $self->run_cmd($cmd);

  return;
}

1;