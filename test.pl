#!/usr/bin/perl
#
#		Test script for Class::Translucent
#		$Id: test.pl,v 1.2 1999/12/02 19:55:24 deveiant Exp $
#
#		Before `make install' is performed this script should be runnable with
#		`make test'. After `make install' it should work as `perl test.pl'
#
#		Please do not commit any changes you make to the module without a
#		successful 'make test'!
#

package translucent_test;
use strict;

BEGIN { 
	$| = 1; 
	print "1..1\n"; 

	use vars qw{$Loaded $Counter};
	$Counter = 0;
}



sub test (&) {
	$Counter++;
	my $code = shift;

	eval { &$code };

	if ( $@ ) {
		print STDERR "$@";
		print "not ";
	}

	print "ok $Counter\n";
}


test {
	use Class::Translucent;
	$Loaded = 1;
};


END { print "not ok 1\n" unless $Loaded; }

__END__
