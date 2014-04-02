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
  developers list at L<http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  L<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::DumpRepeats

=head1 DESCRIPTION

Dumps all repeats

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::DumpConstrainedElements;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::BaseDumpBed);

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    method_link => 'GERP_CONSTRAINED_ELEMENT',
    species_set => 'mammals',
  }
}

sub type {
  return 'constrained_element';
}

sub get_track_def {
  my ($self, $track_name, $big_bed_file) = @_;
  my $assembly = $self->assembly();
  my $species_set = $self->param('species_set');

  return <<DEF;
track ${track_name}
bigDataUrl ${big_bed_file}
shortLabel Constrained elements
longLabel Constrained elements generated against assembly ${assembly} for the ${species_set} species collection
type bigBed
DEF
}

sub get_Features {
  my ($self, $slice) = @_;
  my $dba = $self->get_compara_DBAdaptor();
  my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor();
  my $cea = $dba->get_ConstrainedElementAdaptor();
  
  my $mlss = $mlssa->fetch_by_method_link_type_species_set_name(
    $self->param_required('method_link'), $self->param_required('species_set'));

  my @sorted_features = 
        sort { $a->seq_region_start() <=> $b->seq_region_start() }
        @{$cea->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)};
  return \@sorted_features;
}

sub feature_to_bed_array {
  my ($self, $constrained_element) = @_;
  my $chr_name = $self->get_name_from_Slice($constrained_element->slice());
  my $start = $constrained_element->seq_region_start() - 1;
  my $end = $constrained_element->seq_region_end();
  my $strand = ($constrained_element->strand() == -1) ? '-' : '+';
  my $display_id = '.';
  my $score = int($constrained_element->score());
  $score = 0 if $score < 0;
  $score = 1000 if $score > 1000;
  return [ $chr_name, $start, $end, $display_id, $score, $strand ];
}

1;

