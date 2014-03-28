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

package Bio::EnsEMBL::Pipeline::Bed::SpeciesJson;

use strict;
use warnings;
use JSON qw/decode_json/;
use Bio::EnsEMBL::Utils::IO qw/slurp work_with_file/;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Scalar qw/assert_ref/;

sub new {
	my ($class, $path) = @_;
	return bless({ path => $path }, (ref($class)||$class) );
}

sub path {
	my ($self, $path) = @_;
	$self->{path} = $path if $path;
	return $self->{path};
}

sub has_config {
	my ($self, $dba) = @_;
	my $accession = $dba->get_GenomeContainer()->get_accession();
	return 1 if $exists $self->json()->{$accession};
	return 0;
}

sub get_config {
	my ($self, $dba) = @_;
	my $accession = $dba->get_GenomeContainer()->get_accession();
	return $json->{$accession} if $exists $self->json()->{$accession};
}

sub get_config_from_DBAdaptor {
	my ($self, $dba) = @_;
	my $gc = $dba->get_GenomeContainer();
	my $accession = $gc->get_accession();
	my $json = $self->json();
	return $json->{$accession} if $exists $json->{$accession};
	return $self->build_config_from_DBAdaptor($dba);
}

sub build_config_from_DBAdaptor {
	my ($self, $dba) = @_;
	my $gc = $dba->get_GenomeContainer();
	my $mc = $dba->get_MetaContainer();

	my $config = {};
	$config->{name} = $dba->get_MetaContainer()->get_production_name();
	$config->{accession} = $gc->get_accession();
	$config->{assembly_version} = $gc->get_version();
	$config->{assembly} = $gc->get_assembly_name() || $config->{assembly_version};
	my $gencode = $mc->single_value_by_key('gencode.version');
	$config->{gencode} = $gencode if $gencode;
	$config->{genebuild} = $gc->get_genebuild_last_geneset_update();

	return $config;	
}

# Add a config. Config is optional (we can build it from the dba). DBA is not optional
sub add_config {
	my ($self, $dba, $config) = @_;
	assert_ref($dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor');
	$config //= $self->build_config_from_DBAdaptor($dba);
	$self->json()->{$config->{accession}} = $config;
	return $config;
}

sub json {
	my ($self, $json) = @_;
	return $self->{json} = $json if exists $self->{json};
	return $self->{json} if exists $self->{json};
	my $path = $self->path();
	# don't die if the path isn't there. Build a hash and return
	return $self->{json} = {} unless -f $path;
	my $slurp = slurp($path);
	return $self->{json} = decode_json($slurp);
}

sub write {
	my ($self) = @_;
	my $json = $self->json();
	my $path = $self->path();
	work_with_file($path, 'w', sub {
		my ($fh) = @_;
		my $encoded = JSON->new->pretty->encode($json);
		print $fh $encoded;
		return;
	});
	return;
}

1;