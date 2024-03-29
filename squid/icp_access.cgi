#!/usr/local/bin/perl
# icp_access.cgi
# A form for editing or creating an ICP access restriction

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
my $conf = &get_config();

# Count up ACL users
my %ucount;
foreach my $h (&find_config("icp_access", $conf)) {
	foreach my $v (@{$h->{'values'}}) {
		my $vv = $v;
		$vv =~ s/^\!//;
		$ucount{$vv}++;
		}
	}

my @icp;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'aicp_header'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'aicp_header1'}, "",
		undef, 0, 0, 0, &restart_button());
	@icp = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("icp_access_save.cgi", "post");
if (@icp) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_table_start($text{'aicp_pr'}, undef, 2);

# Allow or deny ACLs
print &ui_table_row($text{'aicp_a'},
	&ui_radio("action", $icp[0] || "allow",
		  [ [ "allow", $text{'aicp_a1'} ],
		    [ "deny", $text{'aicp_d'} ] ]));

# Get list of ACLs being matched, and all ACLs
my (@yes, @no);
for(my $i=1; $i<@icp; $i++) {
	if ($icp[$i] =~ /^!(.*)/) {
		push(@no, $1);
		}
	else {
		push(@yes, $icp[$i]);
		}
	}
my %done;
my @acls = grep { !$done{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
my $r = @acls;
$r = 10 if ($r > 10);

my @opts =  map { my $v = $_->{'values'}->[0];
                  [ $v, $v." (".int($ucount{$v}).")" ] } @acls;
print &ui_table_row($text{'aicp_ma'},
	&ui_select("yes", \@yes, \@opts, $r, 1, 1));

print &ui_table_row($text{'aicp_dma'},
	&ui_select("no", \@no, \@opts, $r, 1, 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ],
		     @icp ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("edit_acl.cgi?mode=icp", $text{'aicp_return'},
		 "", $text{'index_return'});

