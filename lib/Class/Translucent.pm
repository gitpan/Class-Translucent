#!/usr/bin/perl -w
##############################################################################

=head1 NAME

Class::Translucent - A base class for translucency

=head1 SYNOPSIS

    package My::Class;
    BEGIN {
        use Class::Translucent  ({
            name    => 'sparrow',
            item2   => 'else',
            attr    => { one => 'two', two => 'three', three => 'one' },
            events  => [ 'buy', 'grow', 'sell', 'eat', 'sleep' ],
        });

        use base qw{Class::Translucent};
    }


    sub new {
        my $self = shift;

        return $self->SUPER::new( @_ );
    }

    package main;

    my $o = new My::Class;
    print $o->name;             # Prints 'sparrow'
    $o->name( 'robin' );        # Set the per-object value
    print $o->name;             # Prints 'robin'
    print My::Class->name;      # Prints 'sparrow'

=head1 EXPORTS

Nothing by default.

=head1 REQUIRES

L<Carp>, L<Data::Dumper>

Actually, Data::Dumper is only required for debugging, so this module will
eventually only need Carp.

=head1 DESCRIPTION

This is an abstract base class that provides functionality for translucent
attributes in its derivatives. A translucent attribute is an attribute which
has a class-wide default. A class's attributes are set in a template, from
which all class and instance method calls initially get/set their
data. However, once an object has stored a value, it loses its translucency,
and thereafter returns its own distinct value. For more information about
translucency, see Tom Christiansen's excellent I<OO Tutorial for Class Data in
Perl>, which can be found at
E<lt>http://language.perl.com/misc/perltootc.htmlE<gt>.

In order for your class to usefully inherit from Class::Translucent, it needs to
tell Class::Translucent about itself via a template. This template should be a
hash or hash reference containing keys for all the translucent attributes of
your class, along with default values for each one.

There are several methods for defining this template. If you have class data
that needs to be accessed before any instances of your class are created, you
can pass the template as the argument to the 'use' statement, like so:

    use Class::Translucent ({ attribute => 'defaultValue' });

You can also define a package global named the same thing as the last part of
your package (eg., if you class is called C<HTML::Graphics::Vector>, the hash
should be C<%HTML::Graphics::Vector::Vector>). When Class::Translucent's
constructor is called as a superclass constructor from your class (or one of its
parent classes) and it doesn't already have a template registered for your class,
it will look for such a hash, and if it is found, use it as the class's template.

In any case, as soon as the template is defined, Class::Translucent
auto-generates translucent accessor methods for the attributes you've specified in
the template, skipping any that may already be defined.

The constructor returns an empty hashref blessed into the calling class.

I<TODO: More docs>

=head1 AUTHOR / PERSON TO BLAME

Michael Granger E<lt>ged@FaerieMUD.orgE<gt> based on ideas from I<Tom's
OO Tutorial for Class Data in Perl> (L<perltootc>) by Tom Christiansen.

Copyright (c) 1999, 2000, The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or
redistribute this software under the terms of the Perl Artistic
License. (See http://language.perl.com/misc/Artistic.html)

=head1 TO DO

=over 4

=item *

Do template interpolation in the method template accessor methods instead of in
the code generation itself. This would mean that subclassing would not obligate
one to returning templates.

=item *

Add per-class translucent data so that derivative class B's attributes are
inherited from superclass A, but remain distinct for each class. Can probably
accomplish this by iterating over @{"${class}::ISA"}, and fetching the parent
class's hash and merging it with our own.

=item *

Package-qualify object data members ala Damian Conway's C<Tie::SecureHash>.

=item *

Better documentation

=item *

Better test suite (or any test suite?)

=back

=head1 BUGS

=over 4

=item Unintuitive translucency with complex datatypes

Operations other than a simple set() are ambiguous for complex datatypes. For
example, C<push> adds an element to an array -- so if an array attribute is
translucent, should C<pushAttribute()> called as an object method push the given
value onto a new empty array, or should it make a copy of the class data first,
and push the new element onto it?

THe copy-on-write behaviour is the current behaviour, but will need some rigorous testing
to make sure it conforms to Perl's do-what-I-mean.

=item Cluttered BEGIN blocks

In order for class methods to be callable immediately after the C<use
Class::Translucent>, the C<import()> function must do the method
generation. This requires that the class template be mangled into the argument
to C<use>, which is perhaps ugly and unintuitive to some. I can't see any way
around it, though, as it has to occur in a BEGIN block in order to guarantee
that the generated methods exist before the constructor is called. Otherwise,
setting class-wide data must wait until the first instance is created.

=item "Subroutine 'I<sub>' redefined..." warnings with overridden methods

Accessor methods for translucent attributes are generated at load time, and
overriding subs are defined after that. This can cause warnings to be issued
when the methods are encountered in the derived class. This problem doesn't
exist when the methods are created during the call to the constructor, as the
method-generation code won't clobber a method which is already defined, but then
you have to guarantee that no method will be called as a class method before the
first object is constructed. You could resort to calling the constructor from
within the package itself, but ACK! =:) Things will still work as is, but
spurious warnings can be confusing for those who don't RTFM.

You can also cause the warnings to disappear by prototyping the methods you wish
to override before the C<use Class::Translucent> call, but that's unintuitive.

=item Reload problems

When redefining a class during a reload, there is no current mechanism for
re-generating the accessor methods. There should be some method that can be
called which will clear at least the C<%Classes> hash in the closure so a
class's template can be reloaded. Perhaps some mechanism for clobbering existing
accessors would also be desirable.

Another related problem -- do Perl internals care if a method gets clobbered?
Does Perl do caching of method lookups, and, if so, what will happen if the
cached method is undefined during the life of the program? Randal Schwartz
suggests modifying the @ISA, which will cause cached methods to be discarded,
but I haven't yet tested this.

=back

=cut

##########################################################################
package Class::Translucent;
use strict;


###############################################################################
###  I N I T I A L I Z A T I O N
###############################################################################
BEGIN {

	require 5.006;
	use Carp			qw{croak confess carp};
	use Data::Dumper	qw{};

	### Versioning stuff and custom includes
	use vars qw{$VERSION $RCSID $AUTOLOAD $Debug @ISA};

	$VERSION	= do { my @r = (q$Revision: 1.18 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
	$RCSID		= q$Id: Translucent.pm,v 1.18 2002/08/08 20:07:59 deveiant Exp $;

	$Debug		= 0;

	### Inheritance
	@ISA		= qw{UNIVERSAL};
}


###############################################################################
###  C O N F I G U R A T I O N   ( G L O B A L S )
###############################################################################
our (
	 %MethodTemplates,
	 %AccessCheck,
	 %AccessorCode,
	 %Classes,
	 %SuperMethod,
	);

### (CONFIGURATION) GLOBAL: %AccessorCode
### Method generation templates for the scoping part of the generated
###		methods. Attributes with a leading capital are considered to
###		be of class scope only, and calls to its accessors always
###		modify and/or return the class data. All other attributes are
###		considered translucent, and reference the class data if no
###		specific value has been set for the object in which the
###		accessor was called, or if the accessor method is called as a
###		class rather than an instance method.
### The code in these templates can contain the same tokens as the
###		C<%AccessCheck> global, and they are subject to the same
###		substitution at method-generation.
### Note that the attribute passed to later chunks of the method will
###		B<always> be a reference to the needed attribute, even if the
###		attribute is already a reference. This is to make it easier
###		later on to modify the attribute without knowing exactly where
###		the thing being modified lives.
%AccessorCode = (
	class		=> q{
		my $attribute = \$Classes{'%% CLASS %%'}{%% ATTRIBUTE %%};
	},
	instance	=> q{
		my $attribute;
		if ( not ref $self ) {
			$attribute = \$Classes{'%% CLASS %%'}{%% ATTRIBUTE %%};
		} else {
			if ( @_ && ! exists $self->{%% ATTRIBUTE %%} ) {
				$self->{%% ATTRIBUTE %%} = $Classes{'%% CLASS %%'}{%% ATTRIBUTE %%};
			}

			if ( @_ || exists $self->{%% ATTRIBUTE %%} ) {
				$attribute = \$self->{%% ATTRIBUTE %%};
			} else {
				$attribute = \$Classes{'%% CLASS %%'}{%% ATTRIBUTE %%};
			}
		}
	},
);

### (STATIC) METHOD: AccessorCode( $accessorType )
### Return a method generation template for the scoping part of a generated
###		method based on the accessor type specified. If the accessor type is
###		'class', a template appropriate for static methods is returned. If the
###		specified type is 'instance', then a template appropriate for instance
###		methods is returned. See the configuration global of the same name for
###		more information.
sub AccessorCodeTemplate {
	my $class = shift;
	my $type = shift or return undef;

	return exists $AccessorCode{$type}
		? $AccessorCode{$type}
		: undef;
}


### (CONFIGURATION) GLOBAL: %AccessCheck
### Method generation templates for the access-check part of each
###		method. Attributes which are prefixed with a single underscore
###		('C<_>') are considered 'protected', and the accessor methods
###		generated for it may only be called from within the defining
###		class or one of its derivatives. Attributes which are prefixed
###		with two or more underscores are considered 'private', and may
###		only be accessed from within the defining class itself. All
###		other attributes are considered public, and may be accessed
###		from any package.
### The code contained in these templates contain special tokens 'C<%%
###		ATTRIBUTE %%>', and 'C<%% CLASS %%>', which will be replaced,
###		respectively, with the attribute name and the name of the
###		class for which they are being generated.
%AccessCheck = (
	private		=> q{
		my $class = ref $self || $self;
		my $caller = caller;
		croak "Illegal access to private method '%% ATTRIBUTE %%' of '%% CLASS %%' from package '$caller'"
			if $caller ne '%% CLASS %%';
	},
	protected	=> q{
		my $class = ref $self || $self;
		my $caller = caller;
		croak "Illegal access to protected method '%% ATTRIBUTE %%' of '%% CLASS %%' from package '$caller'"
			unless UNIVERSAL::isa( $caller, '%% CLASS %%' );
	},
	public		=> q{
	},
);


### (STATIC) METHOD: AccessCheck( $accessorType )
### Return a method generation template for the access-check part of a generated
###		method based on the accessor type specified. The type can be one of
###		'public', 'protected', or 'private'. See the configuration global of the
###		same name for more information.
sub AccessCheckTemplate {
	my $class = shift;
	my $type = shift or return undef;

	return exists $AccessCheck{$type}
		? $AccessCheck{$type}
		: undef;
}


### (CONFIGURATION) GLOBAL: %MethodTemplates
### Method generation templates for various datatypes, keyed by
###		type. These templates are used to create the meat of the
###		generated accessor methods. The code they contain will be
###		passed a reference to the attribute to operate on in a scalar
###		called C<$attribute>, and the rest of the argument list will
###		be untouched.
### The word 'attribute' in the key is replaced in the generated
###		method with the name of the attribute. For example, if you had
###		a key named 'bargleAttribute', an attribute called 'name'
###		would result in a generated method called
###		'bargleName'. Leading underscores in an attribute name are
###		always translated to the beginning of the method name, so if
###		the attribute above was instead called '__name', then the
###		generated method would be '__bargleName'. Attributes with
###		leading capitalization result in leading capitalization in the
###		generated method name as well. Eg., an attribute called 'Name'
###		would result in a method named 'BargleName', and an attribute
###		called '_Name' would generate a method called '_BargleName'.
### The methods in the 'default' key/value pair are given to every
###		datatype, and can be overidden by the more specific datatype
###		key/value pair. This can be used to establish some default
###		behaviour for an accessor, and then override it for specific
###		datatypes.
%MethodTemplates = (

	### Array attributes (push, pop, shift, unshift, splice, and slice
	###		elements of the attribute hash)
	ARRAY	=> {
		pushAttribute		=> q{
			return push @$$attribute, @_;
		},
		popAttribute		=> q{
			return pop @$$attribute;
		},
		shiftAttribute		=> q{
			return shift @$$attribute;
		},
		unshiftAttribute	=> q{
			return unshift @$$attribute, @_;
		},
		spliceAttribute		=> q{
			my $offset = shift;
			my $length = shift;
			my @array = @_;
			return splice @$$attribute, $offset, $length, @array;
		},
		sliceAttribute		=> q{
			my @indexes = @_;
			return wantarray ? @$$attribute[ @indexes ] : [@$$attribute[ @indexes ]];
		},
		attribute			=> q{
			if ( @_ ) { $$attribute = shift }
			return wantarray ? @$$attribute : $$attribute;
		},
	},

	### Hash attributes (delete, set, and get individual keys of the hash)
	HASH	=> {
		deleteAttribute		=> q{
			my @rvals = ();
			foreach my $key ( @_ ) {
				push @rvals, ${$attribute}->{$key};
				delete ${$attribute}->{$key}
			}
			return wantarray ? @rvals : \@rvals;
		},
		setAttribute		=> q{
			my %args = @_;
			foreach my $key ( keys %args ) { ${$attribute}->{ $key } = $args{ $key } }
			return keys %args;
		},
		getAttribute		=> q{
			my @rvals = ();
			foreach my $key ( @_ ) {
				push @rvals, exists ${$attribute}->{ $key }
							 ? ${$attribute}->{ $key }
							 : undef;
			}
			return wantarray ? @rvals : \@rvals;
		},
		attribute			=> q{
			if ( @_ ) { $$attribute = shift }
			return wantarray ? %$$attribute : $$attribute;
		},
	},

	### Default templates (plain get/set accessor)
	default	=> {
		attribute			=> q{
			if ( @_ ) {	$$attribute = shift }

			return $$attribute;
		},
	},
);


### (STATIC) METHOD: MethodTemplates( $dataType )
### Return a hashref of method generation templates for the specified
###		datatype. See the documentation for the MethodTemplate configuration
###		hash for more information.
sub MethodTemplates {
	my $class = shift;
	my $type = shift || 'default';

	### Get the generic accessor method templates, and then merge the ones for
	###		specific datatypes into 'em.
	my %methodHash = %{$MethodTemplates{default}};
	%methodHash = ( %methodHash, %{$MethodTemplates{$type}} )
		if exists $MethodTemplates{$type};

	return \%methodHash;
}



### METHOD: import( \%template )
### Autogenerates methods for the calling class. This method can
###		either be called automatically from a C<use> statement, or
###		can be called explicitly. Note that overriding one of the
###		methods provided by this function may result in a
###		'subroutine redefined' warning, as they won't yet exist
###		when C<import()> is called, typically. This is probably
###		harmless.

### METHOD: importToLevel( $level, \%template )
### Autogenerates methods for the class indicated by the stackframe specified by
###		level. This can be useful when you want to override the import() method,
###		but still use Class::Translucent's method generation. Idea borrowed from
###		Exporter's export_to_level().

###	(CONSTRUCTOR) METHOD: new( @args )
### Create and return a new hash reference blessed into your
###		class. If accessors have not already been generated for
###		your class, they will be generated from the
###		constructor. Existing (overridden) methods will be
###		preserved.

### (PROTECTED) METHOD: _buildAccessors( $class[, \%template] )
### Build translucent data accessor methods for the specified
###		class (package), using the template specified either by
###		the optional second argument, or if the second argument is
###		not passed, the template as defined in the class
###		itself. This template should be synonymous with the last
###		part of the package name, so that the template for
###		C<My::Derived::Class> will be called
###		C<%My::Derived::Class::Class>. This function

### (PROTECTED) METHOD: _buildMethodCode( $attributeName, $codeTemplate, $package )
###	Build code for a method specified by the attribute name, with the specified
###		code template and bound for the specified package.

### (PROTECTED) METHOD: _makeMethodName( $attribute, $methodPrototype )
### Make and return a method name for the specified attribute with the specified
###		method name prototype.
TRANSLUCENT_SCOPE: {

	# Doesn't work under mod_perl and other fork()ing environments
	#our %Classes = ();
	#our %SuperMethod = ();

	sub import {
		my $self = shift;
		my $class = caller;
		my $template = shift;

		_debugMsg( "Importing for $class." );
		_debugMsg( "Imported ", Data::Dumper->Dumpxs( [$template], [qw{template}] ), "." )
			if defined $template;

		_buildAccessors( $class, $template ) unless exists $Classes{ $class };
	}


	sub importToLevel {
		my $self = shift;
		my $level = shift || 1;
		my $class = caller( $level );
		my $template = shift;

		_debugMsg( "Importing to level $level ($class)." );
		_debugMsg( "Imported ", Data::Dumper->Dumpxs( [$template], [qw{template}] ), "." )
			if defined $template;

		_buildAccessors( $class, $template ) unless exists $Classes{ $class };
	}


	sub new {
		my $proto = shift;
		my $class = ref $proto || $proto;
		my %attributes = @_;

		### Bitch about being instantiated ourselves
		carp "Instantiation attempted of abstract class '", __PACKAGE__, "'"
			if $class eq __PACKAGE__;

		### Build accessors for the class if we've not yet seen it for some
		### reason
		_debugMsg( "Class definition for '$class' already exists. Not building accessors." )
			if exists $Classes{ $class };
		_buildAccessors( $class ) unless exists $Classes{ $class };
		my $object = bless( (ref $proto ? { %$proto  } : {}), $class );

		### Iterate over any pseudohash keys we got, calling the
		### appropriate method for each
		foreach my $method ( keys %attributes ) {
			$object->$method( $attributes{$method} );
		}

		return $object;
	}


	sub AUTOLOAD {
		my $self = shift or carp "AUTOLOAD reached as function call";
		my (
			$package,
			$method,
			$methodName,
		   );

		### Figure out which method we're supposed to be
		( $method = $AUTOLOAD ) =~ s{.*::}{};
		$package = ref $self || $self;
		$methodName = sprintf '%s::%s', $package, $method;

		confess "Could not access method '$method' in the '$package' class (",
			scalar keys %SuperMethod, " SuperMethods defined)"
			unless exists $SuperMethod{ $methodName };
		confess "Super method for '$methodName is not a coderef: bailing out"
			unless ref $SuperMethod{ $methodName } eq 'CODE';

		### Call the default accessor method with the arguments given and return
		### the result
		return $SuperMethod{$methodName}->( $self, @_ );
	}


	sub _buildAccessors {
		my $package = shift;
		my $template = shift;

		### Sanity-check the template argument
		croak( "Template argument must be an anonymous hash ref if present, not a ",
			   (ref $template ? ref $template : "simple scalar ($template)") )
			if defined $template and ref $template ne 'HASH';

		### Declare local variables
		my (
			%methodHash,		# The hash of methods for the current datatype
			$buildClass,		# The class for which we're builing methods
			$subroutine,		# The eval'ed code of the built method
			$methodCount,		# The number of generated methods
			$classData,			# Reference to the class data hash
			$datatype,			# The data type of the attribute we're accessing
		   );

		### Localize so it exists in the symbol table, and we can alias it later
		our %template;

		### Trim off the package specification from the class name, and create a new hash in the
		###		class data table
		( $buildClass = $package ) =~ s/.*:://;
		$classData = $Classes{$package} = {};

		### If they didn't pass a template, look for a synonymous hash
		### in their package. If they did, just dereference it.
		if ( !defined $template ) {

			_debugMsg( "Template for '", $package, "' is undefined." );
			no strict 'refs';

			### If they don't have a class template in their package either, we
			###		don't need to create any methods, so delete the class from
			###		our list and abort
			delete $Classes{$package}, return 0
				unless defined %{ "${package}::${buildClass}" };

			### Alias the template hash to something more manageable
			*template = *{ "${package}::${buildClass}" };
		} else {
			%template = %$template;
		}

		### Iterate over each attribute, creating accessor methods
		###		for each
		###	:TODO: Would an evaled sub be much slower? It sure would
		###		save some lines and reduce complexity a bit...
		foreach my $attribute ( keys %template ) {

			### Set the default class data based on the template, and
			###		figure out what set of methods we're building
			$classData->{ $attribute } = $template{ $attribute };
			$datatype = ref $template{ $attribute };
			%methodHash = %{__PACKAGE__->MethodTemplates( $datatype )};
			$methodCount = 0;

			### Now iterate over each method we're creating, building
			###		it out of spare parts from our parts hashes,
			###		eval'ing each one, and finally sticking it in the
			###		correct package via a glob on the new method name
			foreach my $methodProto ( keys %methodHash  ) {

				my $methodName = __PACKAGE__->_makeMethodName( $attribute, $methodProto );
				my $methodCode = __PACKAGE__->_buildMethodCode( $attribute,
																$methodHash{ $methodProto },
																$package );

				_debugMsg( "Method code for ${package}::${methodName} is:\n",
						   '-' x 80, "\n$methodCode\n", '-' x 80, "\n\n" );

				### Now eval the method code, aborting on any error
				$subroutine = eval $methodCode;
				confess "Failed evaluation of method '$methodName' for $package: $@"
					if $@;

				### Now test for an overidden method by the name we're
				### generating. If we find one, we create the default accessor
				### as a supermethod. If it doesn't exist, graft it into the
				### correct place in the symbol table.
			  NO_STRICT: {
					no strict 'refs';
					my $test = *{ "${package}::${methodName}" };

					$SuperMethod{ "${package}::${methodName}" } = $subroutine;

					### If the method is not already defined in the target class
					### or one of its superclasses, stick it into the target
					### class's symbol table slot
					unless ( defined &test || $package->can($methodName) ) {
						*{ "${package}::${methodName}" } = $subroutine;
					}
				}

				$methodCount++;
			}
		}

		return $methodCount;
	}


	sub _makeMethodName {
		my ( $self, $attribute, $methodProto ) = @_;

		my (
			$underscores,
			$letters,
			$methodName,
		   );

		### Dissect the attribute and splice it into the
		###		prototypical method to derive the actual name
		###		of the method we're building. We shuffle
		###		leading underscores to the front of the name,
		###		and duplicate the capitalization convention of
		###		the attribute in the method name. Eg.,
		###			itemName => getItemName
		###		and
		###			ItemName => GetItemName
		( $underscores, $letters ) = $attribute =~ m{^(_*)(.+)};
		( $methodName = $methodProto ) =~ s{attribute}{$letters}g;
		$methodName =~ s{Attribute}{ ucfirst $letters }eg;
		$methodName = ucfirst $methodName if $letters =~ m{^[A-Z]};
		$methodName = "${underscores}${methodName}" if $underscores;

		return $methodName;
	}


	sub _buildMethodCode {
		my ( $self, $attribute, $codeTemplate, $package ) = @_;

		### Start out the code with a little static chunk
		my $methodCode = qq{sub \{\n\tmy \$self = shift;\n};

		### Pick an access-check code chunk based on the
		###		attribute name
		if ( $attribute =~ m{^__} ) {
			$methodCode .= __PACKAGE__->AccessCheckTemplate('private');
		} elsif ( $attribute =~ m{^_} ) {
			$methodCode .= __PACKAGE__->AccessCheckTemplate('protected');
		} else {
			$methodCode .= __PACKAGE__->AccessCheckTemplate('public');
		}

		### Pick an accessor depending on whether it's a class
		###		or instance method
		if ( $attribute =~ m{^_*[A-Z]} ) {
			$methodCode .= __PACKAGE__->AccessorCodeTemplate('class');
		} else {
			$methodCode .= __PACKAGE__->AccessorCodeTemplate('instance');
		}

		### Now tack on the rest of the template and fill it in
		$methodCode .= qq{$codeTemplate\n\n\}};
		$methodCode =~ s{%% CLASS %%}{$package}g;
		$methodCode =~ s{%% ATTRIBUTE %%}{$attribute}g;

		return $methodCode;
	}

}



###############################################################################
###  P R I V A T E   M E T H O D S
###############################################################################



###############################################################################
###  P U B L I C   F U N C T I O N S
###############################################################################



###############################################################################
###  P R I V A T E   F U N C T I O N S
###############################################################################

sub _debugMsg {
	return unless $Debug && @_;
	my $message = join( '', @_ ) || 'Mark.';

	my ( $pkg, $file, $line, $sub ) = (caller( 0 ))[0..2];
	( undef, undef, undef, $sub ) = caller( 1 );

	print STDERR ">> DEBUGMSG ${sub} ($pkg line $line): $message\n";
}


###############################################################################
###  P A C K A G E   A N D   O B J E C T   D E S T R U C T O R S
###############################################################################
sub DESTROY {}
sub END {}


### The package return value (required)
1;


###############################################################################
###  D O C U M E N T A T I O N
###############################################################################

###	AUTOGENERATED DOCUMENTATION FOLLOWS

=head1 GLOBALS

=head2 Configuration Globals

=over 4

=item I<%AccessCheck>

Method generation templates for the access-check part of each
method. Attributes which are prefixed with a single underscore
('C<_>') are considered 'protected', and the accessor methods
generated for it may only be called from within the defining
class or one of its derivatives. Attributes which are prefixed
with two or more underscores are considered 'private', and may
only be accessed from within the defining class itself. All
other attributes are considered public, and may be accessed
from any package.

The code contained in these templates contain special tokens 'C<%%
ATTRIBUTE %%>', and 'C<%% CLASS %%>', which will be replaced,
respectively, with the attribute name and the name of the
class for which they are being generated.

=item I<%AccessorCode>

Method generation templates for the scoping part of the generated
methods. Attributes with a leading capital are considered to
be of class scope only, and calls to its accessors always
modify and/or return the class data. All other attributes are
considered translucent, and reference the class data if no
specific value has been set for the object in which the
accessor was called, or if the accessor method is called as a
class rather than an instance method.

The code in these templates can contain the same tokens as the
C<%AccessCheck> global, and they are subject to the same
substitution at method-generation.

Note that the attribute passed to later chunks of the method will
B<always> be a reference to the needed attribute, even if the
attribute is already a reference. This is to make it easier
later on to modify the attribute without knowing exactly where
the thing being modified lives.

=item I<%MethodTemplates>

Method generation templates for various datatypes, keyed by
type. These templates are used to create the meat of the
generated accessor methods. The code they contain will be
passed a reference to the attribute to operate on in a scalar
called C<$attribute>, and the rest of the argument list will
be untouched.

The word 'attribute' in the key is replaced in the generated
method with the name of the attribute. For example, if you had
a key named 'bargleAttribute', an attribute called 'name'
would result in a generated method called
'bargleName'. Leading underscores in an attribute name are
always translated to the beginning of the method name, so if
the attribute above was instead called '__name', then the
generated method would be '__bargleName'. Attributes with
leading capitalization result in leading capitalization in the
generated method name as well. Eg., an attribute called 'Name'
would result in a method named 'BargleName', and an attribute
called '_Name' would generate a method called '_BargleName'.

The methods in the 'default' key/value pair are given to every
datatype, and can be overidden by the more specific datatype
key/value pair. This can be used to establish some default
behaviour for an accessor, and then override it for specific
datatypes.

=back

=head1 METHODS

=over 4

=item I<import( \%template )>

Autogenerates methods for the calling class. This method can
either be called automatically from a C<use> statement, or
can be called explicitly. Note that overriding one of the
methods provided by this function may result in a
'subroutine redefined' warning, as they won't yet exist
when C<import()> is called, typically. This is probably
harmless.

=item I<importToLevel( $level, \%template )>

Autogenerates methods for the class indicated by the stackframe specified by
level. This can be useful when you want to override the import() method,
but still use Class::Translucent's method generation. Idea borrowed from
Exporter's export_to_level().

=back

=head2 Constructor Methods

=over 4

=item I<new( @args )>

Create and return a new hash reference blessed into your
class. If accessors have not already been generated for
your class, they will be generated from the
constructor. Existing (overridden) methods will be
preserved.

=back

=head2 Protected Methods

=over 4

=item I<_buildAccessors( $class[, \%template] )>

Build translucent data accessor methods for the specified
class (package), using the template specified either by
the optional second argument, or if the second argument is
not passed, the template as defined in the class
itself. This template should be synonymous with the last
part of the package name, so that the template for
C<My::Derived::Class> will be called
C<%My::Derived::Class::Class>. This function

=item I<_buildMethodCode( $attributeName, $codeTemplate, $package )>

Build code for a method specified by the attribute name, with the specified
code template and bound for the specified package.

=item I<_makeMethodName( $attribute, $methodPrototype )>

Make and return a method name for the specified attribute with the specified
method name prototype.

=back

=head2 Static Methods

=over 4

=item I<AccessCheck( $accessorType )>

Return a method generation template for the access-check part of a generated
method based on the accessor type specified. The type can be one of
'public', 'protected', or 'private'. See the configuration global of the
same name for more information.

=item I<AccessorCode( $accessorType )>

Return a method generation template for the scoping part of a generated
method based on the accessor type specified. If the accessor type is
'class', a template appropriate for static methods is returned. If the
specified type is 'instance', then a template appropriate for instance
methods is returned. See the configuration global of the same name for
more information.

=item I<MethodTemplates( $dataType )>

Return a hashref of method generation templates for the specified
datatype. See the documentation for the MethodTemplate configuration
hash for more information.

=back

=cut

