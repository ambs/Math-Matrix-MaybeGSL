#!perl

use Test::More tests => 49;
use Math::Matrix::MaybeGSL;

my $m = Matrix->new(10, 20);
isa_ok($m, 'Math::Matrix::MaybeGSL');


my ($rows, $cols) = $m->dim();
is $rows => 10;
is $cols => 20;


$m->assign(1, 1, 100);
is $m->element(1,1), 100;
is $m->element(1,2), 0;

my $m2 = Matrix->new_from_cols( [[1, 2], [3, 4]]);
isa_ok($m, 'Math::Matrix::MaybeGSL');

is $m2->element(1,1), 1;
is $m2->element(2,1), 2;
is $m2->element(1,2), 3;
is $m2->element(2,2), 4;



my $m3 = Matrix->new_from_cols( [[5, 6], [7, 8]]);
my $m4 = $m2->hconcat($m3);
isa_ok($m4, 'Math::Matrix::MaybeGSL');
is $m4->element(1,1), 1;
is $m4->element(2,1), 2;
is $m4->element(1,2), 3;
is $m4->element(2,2), 4;

is $m4->element(1,3), 5;
is $m4->element(2,3), 6;
is $m4->element(1,4), 7;
is $m4->element(2,4), 8;


my $m5 = $m2->vconcat($m3);
isa_ok($m5, 'Math::Matrix::MaybeGSL');
is $m5->element(1,1), 1;
is $m5->element(2,1), 2;
is $m5->element(1,2), 3;
is $m5->element(2,2), 4;

is $m5->element(3,1), 5;
is $m5->element(4,1), 6;
is $m5->element(3,2), 7;
is $m5->element(4,2), 8;


my $m6 = $m2 * $m3;
isa_ok($m6, 'Math::Matrix::MaybeGSL');
#    23   31
#    34   46
is $m6->element(1,1), 23;
is $m6->element(1,2), 31;
is $m6->element(2,1), 34;
is $m6->element(2,2), 46;

my $m7 = $m6->each( sub { $_ = shift; ($_ + $_%2) / 2 });
isa_ok($m7, 'Math::Matrix::MaybeGSL');
is $m7->element(1,1), 12;
is $m7->element(1,2), 16;
is $m7->element(2,1), 17;
is $m7->element(2,2), 23;

my ($v, $r, $c) = $m7->max();
is $v, 23;
is $r, 2;
is $c, 2;

($v, $r, $c) = $m7->min();
is $v, 12;
is $r, 1;
is $c, 1;


my $m8 = Matrix->new_from_rows( [[1, 2], [3, 4]]);
isa_ok($m, 'Math::Matrix::MaybeGSL');

is $m8->element(1,1), 1;
is $m8->element(2,1), 3;
is $m8->element(1,2), 2;
is $m8->element(2,2), 4;


1;
