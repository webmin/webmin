use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Authen::SolarisRBAC',
    'VERSION_FROM'	=> 'SolarisRBAC.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    'LIBS'		=> ['-lsecdb -lsocket -lnsl -lintl'], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '', # e.g., '-I/usr/include/other'
    'CCCDLFLAGS'        => ' ',
    'CCFLAGS'           => ' ',
    'OPTIMIZE'          => ' ',
);
