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

=item type - The type of bed file we are generating. See code for allowed types

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);
use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub fetch_input {
  my ($self) = @_;
    
  throw "Need a species" unless $self->param('species');
  throw "Need a base_path" unless $self->param('base_path');
  throw "Need a bed file to convert" unless $self->param('bed');
  throw "Need to know what type we are converting. Allowed are ".$self->allowed_types() unless $self->param('type');

  throw "No BedToBigBed executable given" 
    unless $self->param('bed_to_big_bed');
  $self->assert_executable($self->param('bed_to_big_bed'));

  return;
}

sub run {
  my ($self) = @_;
  
  my $bed_to_big_bed = $self->param('bed_to_big_bed');
  my $chrom_sizes = $self->chrom_sizes_file();
  my $bed = $self->param('bed');

  my $big_bed_name = $bed;
  $bed =~ s/\.bed$/.bb/;
  
  my $path = $self->_generate_file_name();
  $self->info("Dumping GTF to %s", $path);
  gz_work_with_file($path, 'w', sub {
    my ($fh) = @_;
    my $gtf_serializer = Bio::EnsEMBL::Utils::IO::GTFSerializer->new($fh);

    # Print information about the current assembly
    $gtf_serializer->print_main_header($self->get_DBAdaptor('core'));

    # now get all slices and filter for 1st portion of human Y
    my $slices = $self->get_Slices($self->param('group'), 1);
    while (my $slice = shift @{$slices}) {
      my $genes = $slice->get_all_Genes(undef,undef,1); 
      while (my $gene = shift @{$genes}) {
        $gtf_serializer->print_Gene($gene);
      }
    }
  });

  $self->info(sprintf "Checking GTF file %s", $path);
  $self->_gene_pred_check($path);
  
  # $self->run_cmd("gzip $path");

  $self->info("Dumping GTF README for %s", $self->param('species'));
  $self->_create_README();  
  
  return;
}

sub allowed_types {
  my ($self) = @_;
  return keys %{$self->_types_map()};
}

sub type_to_params {
  my ($self, $type) = @_;
}

sub _types_map {
  return {
    transcript => {
      type => 'bed12+2',
      indexed_fields => [qw//],
      as => <<AS,
table 
"Ensembl genes with a Gene Symbol and human readable name assigned (name will be stable id)"
    (
    string chrom;      "Chromosome (or contig, scaffold, etc.)"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "Stable ID of the transcript"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
    uint thickStart;   "Start of where display should be thick (start codon)"
    uint thickEnd;     "End of where display should be thick (stop codon)"
    uint reserved;     "Used as itemRgb as of 2004-11-22"
    int blockCount;    "Number of blocks"
    int[blockCount] blockSizes; "Comma separated list of block sizes"
    int[blockCount] chromStarts; "Start positions relative to chromStart"
    string geneStableId; "Stable ID of the gene"
    string display; "Display label for the gene"
)
AS
    },
    repeat => {

    },
  };
}

1;

