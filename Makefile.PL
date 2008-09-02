#! perl -w

use strict ;
require 5.004 ;

$::VERSION = '2.014' ;

use private::MakeUtil;
use ExtUtils::MakeMaker 5.16 ;

UpDowngrade(getPerlFiles('MANIFEST')) 
    unless $ENV{PERL_CORE};

# Modules supplied by this distribution    
my @myModules = qw( IO::Compress::Lzop
                    IO::Uncompress::UnLzop
                  );

# Direct dependencies                  
my @MainPREREQ = qw(
                    IO::Compress::Base
                    IO::Uncompress::Base
                   );

# Get indirect dependencies that will break if we install this version
push @MainPREREQ, FindBrokenDependencies($::VERSION, @myModules)
    unless $ENV{PERL_CORE} ;

my %MainPREREQ = map { $_ => $::VERSION } @MainPREREQ; 

    
WriteMakefile( 
    NAME         => 'IO::Compress::Lzop',
    VERSION_FROM => 'lib/IO/Compress/Lzop.pm',
    'dist'       => { COMPRESS     => 'gzip', 
                      TARFLAGS     => '-chvf',
                      SUFFIX       => 'gz',
                      DIST_DEFAULT => 'MyTrebleCheck tardist',
                    },

    (
      $ENV{SKIP_FOR_CORE}
        ? (MAN3PODS    => {})
	    : (PREREQ_PM   => { 'Compress::LZO'        => 0,
		                    %MainPREREQ,
		                    $] >= 5.005 && $] < 5.006   
                                ? ('File::BSDGlob' => 0) 
                                : () }
	      )
    ),
       
    (
    $] >= 5.005
        ? (ABSTRACT_FROM => 'lib/IO/Compress/Lzop.pm',
            AUTHOR       => 'Paul Marquess <pmqs@cpan.org>')
        : ()
    ),


    ((ExtUtils::MakeMaker->VERSION() gt '6.30') ?
        ('LICENSE'  => 'perl')         : ()),    


) ;

# end of file Makefile.PL

