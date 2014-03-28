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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::Tabix

=head1 DESCRIPTION

Compresses an input file using bgzip and then indexes it using tabix

Allowed parameters are:

=over 8

=item bed - Path to the bed file we are converting

=item bgzip - Location of the block gzip binary

=item tabix - Location of the tabix binary

=item format_type - The format type. Defaults to bed (should be used in the -s param to tabix)

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::Tabix;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);
use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub param_defaults {
  return {
    format_type => 'bed',
  };
}

sub fetch_input {
  my ($self) = @_;
  throw "Need a bed file to convert" unless $self->param_is_defined('bed');
  $self->assert_executable('bgzip');
  $self->assert_executable('tabix');
  return;
}

sub run {
  my ($self) = @_;
  my $bgzip = $self->run_bgzip();
  $self->run_tabix($bgzip);
  return;
}

sub run_bgzip {
  my ($self) = @_;
  my $bgzip = $self->param('bgzip');
  my $file = $self->param('bed');

  my $final_file = "${file}.gz";
  return $final_file if -f $final_file;
  
  throw "'${file}' bed file does not exist. Cannot continue" unless -f $file;

  my $cmd = sprintf('%s %s', $bgzip, $file);
  $self->run_cmd($cmd);
  return $final_file;
}

sub run_tabix {
  my ($self, $bgzip) = @_;
  throw "'${bgzip}' bed.gz file does not exist. Cannot continue" unless -f $bgzip;
  my $cmd = sprintf('%s -p %s %s', $self->param('tabix'), $self->param('format_type'), $bgzip);
  $self->run_cmd($cmd);
  return;
}

1;

