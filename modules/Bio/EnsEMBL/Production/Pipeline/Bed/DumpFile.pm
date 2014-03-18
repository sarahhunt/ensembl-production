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

Bio::EnsEMBL::Production::Pipeline::Bed::DumpFile

=head1 DESCRIPTION

The main workhorse of the Bed dumping pipeline.

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item group - The database group to dump from

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file gz_work_with_file/;
use File::Path qw/rmtree/;

sub param_defaults {
  return {
    group => 'core',
  };
}

sub fetch_input {
  my ($self) = @_;
    
  throw "Need a species" unless $self->param('species');
  throw "Need a release" unless $self->param('release');
  throw "Need a base_path" unless $self->param('base_path');

  throw "No gtfToGenePred executable given" 
    unless $self->param('gtf_to_genepred');
  $self->assert_executable($self->param('gtf_to_genepred'));

  throw "No genePredCheck executable given" 
    unless $self->param('gene_pred_check');
  $self->assert_executable($self->param('gene_pred_check'));

  return;
}

sub run {
  my ($self) = @_;
  
  my $root = $self->data_path();
  if(-d $root) {
    $self->info('Directory "%s" already exists; removing', $root);
    rmtree($root);
  }

  my $path = $self->_generate_bed_file_name();
  $self->info("Dumping BED to %s", $path);
  gz_work_with_file($path, 'w', sub {
    my ($fh) = @_;
    
    # now get all slices and filter for 1st portion of human Y
    my $slices = $self->get_Slices($self->param('group'), 1);
    while (my $slice = shift @{$slices}) {
      my $genes = $slice->get_all_Genes(undef,undef,1); 
      while (my $gene = shift @{$genes}) {
        # Fit in here
      }
    }
  }); 
  
  return;
}

sub _generate_bed_file_name {
  my ($self) = @_;
  return $self->generate_file_name('bed');
}

sub _generate_bigbed_file_name {
  my ($self) = @_;
  return $self->generate_file_name('bb');
}

1;

