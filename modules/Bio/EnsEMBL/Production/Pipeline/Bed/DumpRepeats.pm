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

package Bio::EnsEMBL::Production::Pipeline::Bed::DumpRepeats;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::BaseDumpBed);

sub type {
  return 'repeat';
}

sub get_track_def {
  my ($self, $track_name, $big_bed_file) = @_;
  my $assembly = $self->assembly();
  return {
    track => $track_name,
    bigDataUrl => $big_bed_file,
    shortLabel => 'Repeats',
    longLabel => "Repeats generated for ${assembly}",
    type => 'bigBed 6 .'
  };
}

sub get_autosql {
  my ($self) = @_;
  return <<'AS',
table bed6 "Repeats on a genome"
    (
    string chrom;      "Chromosome (or contig, scaffold, etc.)"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "The repeat identifier"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
)
AS
}

sub get_bed_type {
  return 'bed6';
}

sub get_Features {
  my ($self, $slice) = @_;
  my @sorted_features = 
        sort { $a->seq_region_start() <=> $b->seq_region_start() }
        @{$slice->get_all_RepeatFeatures()};
  return \@sorted_features;
}

sub feature_to_bed_array {
  my ($self, $repeat) = @_;
  return $self->scored_feature_to_bed_array($repeat);
}

1;

