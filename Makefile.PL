use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		    => 'AI::Prolog',
    'VERSION_FROM'	=> 'lib/AI/Prolog.pm',
    'PREREQ_PM'		=> {
        'aliased'           => 0.11,
        'Clone'             => 0.15,
        'Exporter::Tidy'    => 0.06,
        'Hash::AsObject'    => 0.05,
        'Test::Differences' => 0.47,
        'Test::MockModule'  => 0.04,
        'Text::Balanced'    => 1.95,
    },
    ($] >= 5.005
        ? (ABSTRACT_FROM => 'lib/AI/Prolog.pm', AUTHOR => 'Curtis "Ovid" Poe')
        : ()
    ),
);
