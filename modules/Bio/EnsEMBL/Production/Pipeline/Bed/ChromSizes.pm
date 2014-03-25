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

Produces the Chromosome Sizes which is required by UCSC's bedToBigBed utility. We 
dump sizes in alphabetical order (not that the UCSC utilities expect this but
it is nice to do it and shows how bed files should be stored).

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item ucsc - Dump UCSC formatted names rather than Ensembl

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::ChromSizes;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub param_defaults {
  return {
    ucsc => 1,
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
  my $path = $self->chrom_sizes_file();
  $self->info("Dumping Chromsome Sizes to %s", $path);
  my $ucsc = $self->param('ucsc');
  work_with_file($path, 'w', sub {
    my ($fh) = @_;
    # now get all slices and filter for 1st portion of human Y
    my @slices = 
      sort { $a->[0] cmp $b->[0] } 
      # If UCSC names are wanted then use the get_name_from_Slice() method to convert
      # also add the slice length
      map { my $name = ($ucsc) ? $self->get_name_from_Slice($_) : $_->seq_region_name(); [$name, $_->seq_region_length] } 
      @{$self->get_Slices('core', 1)};

    while (my $slice_array = shift @slices) {
      print $fh join("\t", @{$slice_array}), "\n";
    }
    return;
  }); 
  
  return;
}

1;

