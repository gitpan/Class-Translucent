#!/usr/bin/perl
#
#	Perl Makefile for Class::Translucent
#	$Id: Makefile.PL,v 1.4 2002/08/08 20:06:32 deveiant Exp $
#
#	Invoke with 'perl Makefile.PL'
#
#	See ExtUtils::MakeMaker (3) for more information on how to influence
#	 the contents of the Makefile that is written
#

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME			=> 'Class::Translucent',
    VERSION_FROM	=> 'lib/Class/Translucent.pm',
	PREREQ_PM		=> {
		Data::Dumper	=> 0,
		Carp			=> 0,
	},
	dist		=> {
		TARFLAGS			=> 'cvf',
		COMPRESS			=> 'gzip',
		SUFFIX				=> '.gz',
		DIST_CP				=> 'ln',
		DIST_DEFAULT		=> 'tardist',
		CI					=> "cvs commit",
		RCS_LABEL			=> 'cvs tag release_$(VERSION_SYM)',
	},
);

