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
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use File::Path qw/rmtree/;

sub param_defaults {
  return {
    group => 'core',
  };
}

sub fetch_input {
  my ($self) = @_;
  throw "Need a species" unless $self->param_is_defined('species');
  throw "Need a base_path" unless $self->param_is_defined('base_path');
  return;
}

sub run {
  my ($self) = @_;

  my $path = $self->generate_bed_file_name();
  $self->info("Dumping BED to %s", $path);
  work_with_file($path, 'w', sub {
    my ($fh) = @_;
    
    # now get all slices and filter for 1st portion of human Y
    # my $slices = $self->get_Slices($self->param('group'), 1);
    my $slices = [$self->get_DBAdaptor('core')->get_SliceAdaptor()->fetch_by_toplevel_location('22')];
    my @sorted_slices = 
      map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [$_, $self->get_name_from_Slice($_)] } 
      @{$slices};

    $DB::single=1;;
    while (my $slice = shift @sorted_slices) {
      my @sorted_transcripts = 
        sort { $a->seq_region_start() <=> $b->seq_region_start() }
        @{$slice->get_all_Transcripts(1)};

      while( my $transcript = shift @sorted_transcripts) {
        $self->write_Feature($fh, $transcript);
      }
      last;
    }
  }); 
  
  return;
}

sub feature_to_bed_array {
  my ($self, $feature) = @_;
  my $chr_name = $self->get_name_from_Slice($feature->slice());
  my $start = $feature->seq_region_start() - 1;
  my $end = $feature->seq_region_end();
  my $strand = ($feature->seq_region_strand() == -1) ? '-' : '+'; 
  my $display_id = $feature->display_id();
  return [ $chr_name, $start, $end, $display_id, 0, $strand ];
}

sub _cdna_to_genome {
  my ($self, $transcript, $coord) = @_;
  my @mapped = $transcript->cdna2genomic($coord, $coord);
  my $genomic_coord = $mapped[0]->start();
  return $genomic_coord;
}

sub write_Feature {
  my ($self, $fh, $feature) = @_;
  return unless $feature;
  my $bed_array;
  if($feature->isa('Bio::EnsEMBL::Transcript')) {
    $bed_array = $self->write_Transcript($feature);
  }
  elsif($feature->isa('Bio::EnsEMBL::RepeatFeature')) {
    $bed_array = $self->write_scored_Feature($feature);
  }
  else {
    $bed_array = $self->_feature_to_bed_array($feature);
  }
  my $bed_line = join("\t", @{$bed_array});
  print $fh $bed_line, "\n";
  return 1;
}

sub write_Transcript {
  my ($self, $transcript) = @_;

  # Not liking this. If we are in this situation we need to re-fetch the transcript
  # just so the thing ends up on the right Slice!
  my $new_transcript = $transcript->transfer($transcript->slice()->seq_region_Slice());
  $new_transcript->get_all_Exons(); # force exon loading
  my $bed_array = $self->feature_to_bed_array($transcript);
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
  return $bed_array;
}

sub write_scored_Feature {
  my ($self, $feature) = @_;
  my $bed_array = $self->feature_to_bed_array($feature);
  $bed_array->[4] = $feature->score();
  return $bed_array;
}

1;

