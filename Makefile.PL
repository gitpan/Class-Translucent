#!/usr/bin/perl
#
#	Perl Makefile for Class::Translucent
#	$Id: Makefile.PL,v 1.2 2000/07/17 22:18:24 deveiant Exp $
#
#	Invoke with 'perl Makefile.PL'
#
#	See ExtUtils::MakeMaker (3) for more information on how to influence
#	 the contents of the Makefile that is written
#

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME			=> 'Class::Translucent',
    VERSION_FROM	=> 'Translucent.pm',
	PREREQ_PM		=> {
		Data::Dumper	=> 0,
		Carp			=> 0,
	},
);

