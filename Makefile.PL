use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

my @program;
if (prompt("Do you wish to install the 'aiprolog' shell?", "y") =~ /^[Yy]/) {
    @program = (EXE_FILES => [ "bin/aiprolog" ]);
}

WriteMakefile(
    'NAME'		    => 'AI::Prolog',
    'VERSION_FROM'	=> 'lib/AI/Prolog.pm',
    @program,
    'PREREQ_PM'		=> {
        'aliased'           => 0.11,
        'Clone'             => 0.15,
        'Exporter::Tidy'    => 0.06,
        'Hash::AsObject'    => 0.05,
        'Pod::Usage'        => 1.12,
        'Test::Differences' => 0.47,
        'Test::MockModule'  => 0.04,
        'Text::Balanced'    => 1.95,
    },
    ($] >= 5.005
        ? (ABSTRACT_FROM => 'lib/AI/Prolog.pm', AUTHOR => 'Curtis "Ovid" Poe')
        : ()
    ),
);
