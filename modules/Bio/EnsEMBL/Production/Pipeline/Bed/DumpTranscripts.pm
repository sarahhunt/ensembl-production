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

Bio::EnsEMBL::Production::Pipeline::Bed::DumpTranscripts

=head1 DESCRIPTION

Dumps all transcripts

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::DumpTranscripts;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::BaseDumpBed);

sub type {
  return 'transcript';
}

# File name format looks like:
# <species>.<assembly>.<genebuild>.<type>
# e.g. Homo_sapiens.GRCh37.2013-04.bed
# e.g. Homo_sapiens.GRCh37.GENCODE_19.bed
sub generate_file_name {
  my ($self) = @_;
  my $version = $self->get_DBAdaptor()->get_MetaContainer()->single_value_by_key('gencode.version');
  if($version) {
    $version =~ s/\s+/_/;
  }
  else {
    $version = $self->genebuild();
  }
  return $self->SUPER::generate_file_name($version);
}

sub get_Features {
  my ($self, $slice) = @_;
  my @sorted_transcripts = 
        sort { $a->seq_region_start() <=> $b->seq_region_start() }
        @{$slice->get_all_Transcripts(1)};
  return \@sorted_transcripts;
}

sub feature_to_bed_array {
  my ($self, $transcript) = @_;

  #Get BED array
  my $bed_array = $self->_feature_to_bed_array($transcript);

  # Not liking this. If we are in this situation we need to re-fetch the transcript
  # just so the thing ends up on the right Slice!
  my $new_transcript = $transcript->transfer($transcript->slice()->seq_region_Slice());
  $new_transcript->get_all_Exons(); # force exon loading

  # Start working with the coords
  my $bed_genomic_start = $bed_array->[1]; #remember this is in 0 coords
  my ($coding_start, $coding_end, $exon_starts_string, $exon_lengths_string, $exon_count, $rgb) = (0,0,q{},q{},0,0);
  
  # If we have a translation then we do some maths to calc the start of 
  # the thick sections. Otherwise we must have a ncRNA or pseudogene
  # and that thick section is just set to the transcript's end
  if($new_transcript->translation()) {
    my ($cdna_start, $cdna_end) = ($new_transcript->cdna_coding_start(), $new_transcript->cdna_coding_end);
    if($new_transcript->strand() == -1) {
      ($cdna_start, $cdna_end) = ($cdna_end, $cdna_start);
    }
    # Rules are if it's got a coding start we will use it; if not we use the cDNA
    $coding_start = $self->_cdna_to_genome($new_transcript, $cdna_start);
    $coding_start--; # convert to 0 based coords

    #Same again but for the end
    $coding_end = $self->_cdna_to_genome($new_transcript, $cdna_end);
  }
  else {
    # apparently looking at UCSC's own BED output formats we do not need to bother
    # coverting $coding_start into 0 based coords for this one ... odd
    $coding_start = $new_transcript->seq_region_end();
    $coding_end = $coding_start;
  }

  # Now for the interesting bit. Exons are given relative to the bed start
  # so we need to calculate the offset. Lovely.
  # Also sort exons by start otherwise offset calcs are wrong
  foreach my $exon (sort { $a->seq_region_start() <=> $b->seq_region_start() } @{$new_transcript->get_all_Exons()}) {
    my $exon_start = $exon->seq_region_start();
    $exon_start--; #move into 0 coords
    my $offset = $exon_start - $bed_genomic_start; # just have to minus current start from the genomic start
    $exon_starts_string .= $offset.',';
    $exon_lengths_string .= $exon->length().',';
    $exon_count++;
  }

  #TODO Consider setting RGB

  push(@{$bed_array}, $coding_start, $coding_end, $rgb, $exon_count, $exon_lengths_string, $exon_starts_string);

  #Now get the parent Gene and extract the stable id and display label
  if($transcript->adaptor()) {
    my $gene = $transcript->get_Gene();
    my $display_name = $gene->external_name();
    $display_name //= '.';
    push(@{$bed_array}, $gene->display_id(), $display_name);
  }

  return $bed_array;
}

sub _cdna_to_genome {
  my ($self, $transcript, $coord) = @_;
  my @mapped = $transcript->cdna2genomic($coord, $coord);
  my $genomic_coord = $mapped[0]->start();
  return $genomic_coord;
}

1;

