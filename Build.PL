use strict;
use warnings;
use Module::Build;
# note that Makefile.PL is not build automatically due to
# the prompt() method below

my %requires = (
    'aliased'           => 0.11,
    'Clone'             => 0.15,
    'Exporter::Tidy'    => 0.06,
    'Hash::AsObject'    => 0.05,
    'Pod::Usage'        => 1.12,
    'Regexp::Common'    => 2.119,
    'Test::Differences' => 0.47,
    'Test::Exception'   => 0.20,
    'Test::MockModule'  => 0.04,
    'Test::Warn'        => 0.08,
    'Text::Balanced'    => 1.95,
    'Text::Quote'       => 0.03,
);

my $build = Module::Build->new(
    module_name       => 'AI::Prolog',
    license           => 'perl',
    dist_author       => 'Curtis "Ovid" Poe <ovid@cpan.org>',
    dist_version_from => 'lib/AI/Prolog.pm',
    requires          => \%requires,
    add_to_cleanup    => ['AI-Prolog-*'],
);

print <<"END_NOTE";

The 'aiprolog' shell is optional.  If you choose to install it, Term::ReadLine
and Term::ReadKey will be added to your list of prerequisites.

END_NOTE

if ($build->prompt("Do you wish to install the 'aiprolog' shell?", "y") =~ /^[Yy]/) {
    $build->script_files([ "bin/aiprolog" ]);
    %requires = (
        %requires,
        'Term::ReadLine' => 1.01,
        'Term::ReadKey'  => 2.21,
    );
    $build->requires(\%requires);
}

$build->create_build_script();
