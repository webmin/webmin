use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

require 'nftables-lib.pl';
our (%in, %text);

# acl_security_form(&options)
# Output HTML for editing security options for the nftables module
sub acl_security_form
{
my ($o) = @_;

my $mode =
      $o->{'tables'} eq '*' ? 1
    : $o->{'tables'} =~ /^\!/ ? 2
    : 0;
my @selected = split(/\s+/, $o->{'tables'} || '');
shift(@selected) if ($mode == 2 && @selected && $selected[0] eq '!');
my @table_opts = acl_table_options();

print ui_table_row(
	$text{'acl_tables'},
	ui_radio(
		"tables_def",
		$mode,
		[ [1, $text{'acl_tables_all'}],
		  [0, $text{'acl_tables_sel'}],
		  [2, $text{'acl_tables_nsel'}] ]
	    ).
	    "<br>\n".
	    ui_select("tables", \@selected, \@table_opts, 6, 1),
	3
);

foreach my $a (
	qw(view active create setup chains sets rules raw delete
	   apply bootup import clear quick manual)
    )
{
	print ui_table_row($text{'acl_'.$a}, ui_yesno_radio($a, $o->{$a}));
	}
}

# acl_security_save(&options)
# Parse the form for security options for the nftables module
sub acl_security_save
{
if ($in{'tables_def'} == 1) {
	$_[0]->{'tables'} = '*';
	}
elsif ($in{'tables_def'} == 2) {
	$_[0]->{'tables'} = join(" ", "!", split(/\0/, $in{'tables'}));
	}
else {
	$_[0]->{'tables'} = join(" ", split(/\0/, $in{'tables'}));
	}
foreach my $a (
	qw(view active create setup chains sets rules raw delete
	   apply bootup import clear quick manual)
    )
{
	$_[0]->{$a} = $in{$a} || 0;
	}
}

# acl_table_options()
# Returns saved and active table choices for the ACL editor
sub acl_table_options
{
my %seen;
my @opts;
foreach my $t (get_nftables_save()) {
	push(@opts, [table_acl_name($t), nft_table_spec($t)]);
	$seen{table_acl_name($t)} = 1;
	}
my ($active, $err) = get_active_nftables_save();
if (!$err) {
	foreach my $t (@$active) {
		next if ($seen{table_acl_name($t)}++);
		push(
			@opts,
			[ table_acl_name($t),
			  nft_table_spec($t)." ($text{'active_title'})" ]
		);
		}
	}
return sort { $a->[1] cmp $b->[1] } @opts;
}
