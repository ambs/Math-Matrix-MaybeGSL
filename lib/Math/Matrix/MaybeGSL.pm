# ABSTRACT: Uniform use of Math::MatrixReal and Math::GSL::Matrix.

use strict;
use warnings;

package Math::Matrix::MaybeGSL;

use parent 'Exporter';
our @EXPORT = qw{Matrix};

use overload
       '*=' => '_assign_multiply',
        '*' => '_multiply',
 'fallback' =>   undef;        

sub _choose_matrix_module {
	return 'Math::GSL::Matrix' if $INC{'Math/GSL/Matrix.pm'};
	return 'Math::MatrixReal'  if $INC{'Math/MatrixReal.pm'};

	my @err;

	return 'Math::GSL::Matrix' if eval { require Math::GSL::Matrix; 1; };
    push @err, "Error loading Math::GSL::Matrix: $@";
 
    return 'Math::MatrixReal' if eval { require Math::MatrixReal; 1; };
    push @err, "Error loading JSON::XS: $@";
  
    die join( "\n", "Couldn't load a Matrix module:", @err );
}

sub Matrix { __PACKAGE__ }

sub _call {
	my ($method, $obj, @args) = @_;
	$obj->{matrix}->$method(@args);
}

BEGIN {
	our $matrix_module = _choose_matrix_module();
	my %functions = (
		'any' => {
			new => sub { 
				my (undef, $rows, $cols) = @_;
				return _new( $matrix_module->new($rows, $cols) );
			},
			dim  => sub { _call(dim => @_) },
			each => sub { _new(_call(each => @_)) },
		},
		'Math::GSL::Matrix' => {
			assign        => sub { _call(set_elem => ($_[0], $_[1]-1, $_[2]-1, $_[3])); },
			element       => sub { _call(get_elem => ($_[0], $_[1]-1, $_[2]-1, $_[3])); },
			new_from_cols => sub { _new(_gsl_new_from_cols($_[1])) },			
			new_from_rows => sub { _new(_gsl_new_from_rows($_[1])) },						
			vconcat       => sub { _new(_call(vconcat => $_[0], $_[1]{matrix})) },
			hconcat       => sub { _new(_call(hconcat => $_[0], $_[1]{matrix})) },
			max           => sub { 
				if (wantarray) { 
					my ($v, @pos) = _call(max => @_);
					return ($v, map { $_ + 1 } @pos);
				} else {
					return scalar(_call(max => @_))  
				};
			},
			min           => sub { 
				if (wantarray) { 
					my ($v, @pos) = _call(min => @_);
					return ($v, map { $_ + 1 } @pos);
				} else {
					return scalar(_call(min => @_))  
				};
			},
		},
		'Math::MatrixReal' => {
			assign        => sub { _call(assign        => @_); },
			element       => sub { _call(element       => @_); },
			new_from_cols => sub { _new( $matrix_module->new_from_cols($_[1])) },
			new_from_rows => sub { _new( $matrix_module->new_from_rows($_[1])) },			
			vconcat       => sub { _new( ~((~$_[0]{matrix}) . (~$_[1]{matrix})) ) },
			hconcat       => sub { _new(     $_[0]{matrix}  .   $_[1]{matrix}   ) },
			max           => sub { _mreal_max($_[0]{matrix}) },
			min           => sub { _mreal_min($_[0]{matrix}) },			
		},
	);

    no strict 'refs';

	for my $func (keys %{$functions{$matrix_module}}) {
		# Use Sub::Install later?
		$_ = __PACKAGE__ . "::$func";
		*$_ = $functions{$matrix_module}{$func};
	}
	for my $func (keys %{$functions{any}}) {
		# Use Sub::Install later?
		$_ = __PACKAGE__ . "::$func";
		*$_ = $functions{any}{$func};
	}

}

sub _mreal_max {
	my $matrix = shift;
	my ($rs, $cs) = $matrix->dim();
	return $matrix->max() if ($rs == 1 || $cs == 1);

	my ($m, $r, $c, $v) = ($matrix->[0], 1, 1, undef);

	for my $i (1..$rs) {
		for my $j (1..$cs) {
			if (!$v || $v < $m->[$i-1][$j-1]) {
				$r = $i;
				$c = $j;
				$v = $m->[$i-1][$j-1];
			}
		}
	}

	return wantarray ? ($v, $r, $c) : $v;
}

sub _mreal_min {
	my $matrix = shift;
	my ($rs, $cs) = $matrix->dim();
	return $matrix->min() if ($rs == 1 || $cs == 1);

	my ($m, $r, $c, $v) = ($matrix->[0], 1, 1, undef);

	for my $i (1..$rs) {
		for my $j (1..$cs) {
			if (!$v || $v > $m->[$i-1][$j-1]) {
				$r = $i;
				$c = $j;
				$v = $m->[$i-1][$j-1];
			}
		}
	}

	return wantarray ? ($v, $r, $c) : $v;
}

sub _gsl_new_from_cols { 
	my $cols = shift;

	my $nr_columns = scalar(@$cols);
	my $nr_rows = 0;
	for my $row (@$cols) {
		$nr_rows = scalar(@$row) if @$row > $nr_rows;
	}
	my $m = Math::GSL::Matrix->new($nr_rows, $nr_columns);
	for my $r (0..$nr_rows - 1) {
		for my $c (0..$nr_columns - 1) {
			$m->set_elem($r, $c, $cols->[$c][$r] || 0);
		}
	}
	return $m;
}

sub _gsl_new_from_rows { 
	my $rows = shift;

	my $nr_rows = scalar(@$rows);
	my $nr_columns = 0;
	for my $col (@$rows) {
		$nr_columns = scalar(@$col) if @$col > $nr_columns;
	}
	my $m = Math::GSL::Matrix->new($nr_rows, $nr_columns);
	for my $c (0..$nr_columns - 1) {
		for my $r (0..$nr_rows - 1) {
			$m->set_elem($r, $c, $rows->[$r][$c] || 0);
		}
	}
	return $m;
}

sub _new {
	my $mat = shift;
	return bless { matrix => $mat }, __PACKAGE__;
}

sub _assign_multiply
{
    my($object,$argument) = @_;
 
    return( &_multiply($object,$argument,undef) );
}

sub _multiply {
    my ($object, $argument, $flag) = @_;
 
    $argument = $argument->{matrix} if ref $argument eq __PACKAGE__;
    $object   = $object->{matrix}   if ref $object   eq __PACKAGE__;

    if ((defined $flag) && $flag) {
    	return _new($argument * $object);
    } else {
    	return _new($object * $argument);
    }
}



=head1 SYNOPSIS

   use Math::Matrix::MaybeGSL;

   my $matrix = Matrix->new(3, 4);

   # puts first position of matrix with value 10
   $matrix->assign(1, 1, 10);

   # gets last position of matrix (should hold 0)
   my $l = $matrix->element(3, 4);

=head1 DESCRIPTION

This module interfaces with C<Math::GSL::Matrix> or, if that is not available, C<Math::MatrixReal>.
The idea behind this module is to allow the development of tools that use matrices that will work in
pure Perl (using C<Math::MatrixReal>) or with extra efficiency using C<Math::GSL::Matrix>.

Given the two modules API is quite distinct, this module defines its own API, stealing method names from
both these modules.

=method C<Matrix>

This is a simple function that returns this package name: C<Math::Matrix::MaybeGSL>.
It allows a simple interface as shown below for the constructors.

=method C<new>

Construct a new matrix object. Receives as arguments the number of rows and columns of the
matrix being created.

   my $matrix = Matrix->new(20, 30);

Yes, although the module name is C<Math::Matrix::MaybeGSL>, the C<Matrix> subroutine will 
make it easier to use (shorter name).

=method C<new_from_cols>

Receives a nested list with the matrix elements, one column at a time:

   my $matrix = Matrix->new_from_cols( [[1, 2], [3, 4]]);
   
   returns  [ 1 3 ]
            [ 2 4 ]

=method C<new_from_rows>

Receives a nested list with the matrix elements, one row at a time:

   my $matrix = Matrix->new_from_rows( [[1, 2], [3, 4]]);
   
   returns  [ 1 2 ]
            [ 3 4 ]

=method C<dim>

Returns a list (a pair) with the number of lines and columns of the matrix.

   my ($rows, $columns) = $matrix->dim();

=method C<assign>

Sets a value in a specific position. Note that B<indexes start at 1> unlike Perl and some 
other programming languages.

    # sets the first element of the matrix to 10.
    $matrix->assign(1, 1, 10);

=method C<element>

Retrieves a value from a specific position of the matrix. Note that B<indexes start at 1> unlike
Perl and some other programming languages.

    # retrieves the second element of the first row
    my $val = $matrix->element(1, 2);

=method C<each>

Apply a specific function to every element of the matrix, returning a new one.

    # square all elements
    $squared_matrix = $matrix->each( { shift ** 2 } );

=method C<hconcat>

Concatenates two matrices horizontally. Note they must have the same number of rows.

   $C = $a->hconcat($b);

   if A = [ 1 2 ]  and B = [ 5 6 ]  then C = [ 1 2 5 6 ]
          [ 3 4 ]          [ 7 8 ]           [ 3 4 7 8 ]

=method C<vconcat>

Concatenates two matrices horizontally. Note they must have the same number of rows.

   $C = $a->vconcat($b);

   if A = [ 1 2 ]  and B = [ 5 6 ]  then C = [ 1 2 ]
          [ 3 4 ]          [ 7 8 ]           [ 3 4 ]
                                             [ 5 6 ]
                                             [ 7 8 ]

=method C<max>

Returns the maximum value of the matrix. In scalar context the position is also
returned. For vectors (matrices whose number of rows or columns is 1) only a position value
is returned.

      $max = $matrix->max();
      ($max, $row, $col) = $matrix->max();

=method C<min>

Returns the minimum value of the matrix. In scalar context the position is also
returned. For vectors (matrices whose number of rows or columns is 1) only a position value
is returned.

      $min = $matrix->min();
      ($min, $row, $col) = $matrix->min();

=head1 OVERLOAD

For now only the matrix multiplication is overloaded, in the usual operator, C<*>.
Take attention that matrix multiplication only works if the matrix dimensions are
compatible.

    $m = $a * $b;

=head1 BUGS

At this initial stage of this module, only the methods that I am really needing for my depending applications are 
implemented. Therefore, it might not include the method that you were looking for. Nevertheless, 
send me an e-mail (or open an issue on GitHub) and I'll be happy to include it (given the two
modules support it).

=head1 SEE ALSO

Check C<Math::MatrixReal> and C<Math::GSL::Matrix> documentation.

=cut

1;
