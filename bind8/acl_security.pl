use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

require 'bind8-lib.pl';    ## no critic
# Globals from bind8-lib.pl
our (%config, %text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the bind8 module
sub acl_security_form
{
my ($o) = @_;
my $m = $o->{'zones'} eq '*' ? 1 :
	   $o->{'zones'} =~ /^\!/ ? 2 : 0;

my $conf = &get_config();
my @zones = grep { $_->{'value'} ne "." }
		    &find("zone", $conf);
my @views = &find("view", $conf);
foreach my $v (@views) {
	push(@zones, grep { $_->{'value'} ne "." }
			  &find("zone", $v->{'members'}));
	}
my @zoneopts;
foreach my $z (sort { $a->{'value'} cmp $b->{'value'} } @zones) {
	push(@zoneopts, [ $z->{'value'}, &arpa_to_ip($z->{'value'}) ]);
	}
foreach my $v (sort { $a->{'value'} cmp $b->{'value'} } @views) {
	push(@zoneopts, [ 'view_'.$v->{'value'},
			  &text('acl_inview', $v->{'value'}) ]);
	}

print &ui_table_row($text{'acl_zones'},
	&ui_radio("zones_def", $m,
		  [ [ 1, $text{'acl_zall'} ],
		    [ 0, $text{'acl_zsel'} ],
		    [ 2, $text{'acl_znsel'} ] ])."<br>\n".
	&ui_select("zones", [ split(/\s+/, $o->{'zones'}) ], \@zoneopts, 4, 1),
	3);

if (@views) {
	my @viewopts = [ "_", "&lt;".$text{'acl_toplevel'}."&gt;" ];
	foreach my $v (sort { $a->{'value'} cmp $b->{'value'} } @views) {
		push(@viewopts, [ $v->{'value'}, $v->{'value'} ]);
		}

	print &ui_table_row($text{'acl_inviews'},
		&ui_radio("inviews_def", $o->{'inviews'} eq "*" ? 1 : 0,
			  [ [ 1, $text{'acl_vall'} ],
			    [ 0, $text{'acl_vsel'} ] ])."<br>\n".
		&ui_select("inviews", [ split(/\s+/, $o->{'inviews'}) ], \@viewopts,
			   4, 1),
		3);
	}

print &ui_table_row($text{'acl_types'},
	&ui_opt_textbox("types", $o->{'types'}, 40,
			$text{'acl_types1'}, $text{'acl_types0'}),
	3);

print &ui_table_row($text{'acl_dir'},
	&ui_textbox("dir", $o->{'dir'}, 30)." ".&file_chooser_button("dir", 1).
	"<br>\n".&ui_checkbox("dironly", 1, $text{'acl_dironly'}, $o->{'dironly'}),
	3);

print &ui_table_row($text{'acl_defaults'},
	&ui_yesno_radio("defaults", $o->{'defaults'}));

print &ui_table_row($text{'acl_ztypes'},
	join("", map { &ui_checkbox($_, 1, $text{'acl_ztypes_'.$_}, $o->{$_}) }
		    ("master", "slave", "forward", "delegation")),
	3);

print &ui_table_row($text{'acl_reverse'},
	&ui_yesno_radio("reverse", $o->{'reverse'}));
print &ui_table_row($text{'acl_multiple'},
	&ui_yesno_radio("multiple", $o->{'multiple'}));

print &ui_table_row($text{'acl_ro'},
	&ui_yesno_radio("ro", $o->{'ro'}));
print &ui_table_row($text{'acl_apply'},
	&ui_select("apply",
		   defined($o->{'apply'}) && $o->{'apply'} ne '' ? $o->{'apply'} : 0,
		   [ [ 1, $text{'yes'} ],
		     [ 2, $text{'acl_applyonly'} ],
		     [ 3, $text{'acl_applygonly'} ],
		     [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_file'},
	&ui_yesno_radio("file", $o->{'file'}));
print &ui_table_row($text{'acl_params'},
	&ui_yesno_radio("params", $o->{'params'}));

print &ui_table_row($text{'acl_opts'},
	&ui_yesno_radio("opts", $o->{'opts'}));
print &ui_table_row($text{'acl_delete'},
	&ui_yesno_radio("delete", $o->{'delete'}));

print &ui_table_row($text{'acl_gen'},
	&ui_yesno_radio("gen", $o->{'gen'}));
print &ui_table_row($text{'acl_whois'},
	&ui_yesno_radio("whois", $o->{'whois'}));

print &ui_table_row($text{'acl_findfree'},
	&ui_yesno_radio("findfree", $o->{'findfree'}));
print &ui_table_row($text{'acl_remote'},
	&ui_yesno_radio("remote", $o->{'remote'}));

print &ui_table_row($text{'acl_slaves'},
	&ui_yesno_radio("slaves", $o->{'slaves'}));
print &ui_table_row($text{'acl_dnssec'},
	&ui_yesno_radio("dnssec", $o->{'dnssec'}));

print &ui_table_row($text{'acl_views'},
	&ui_radio("views", defined($o->{'views'}) ? $o->{'views'} : 0,
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_edonly'} ],
		    [ 0, $text{'no'} ] ]),
	3);

if (@views) {
	my $vm = $o->{'vlist'} eq '*' ? 1 :
		 $o->{'vlist'} =~ /^\!/ ? 2 :
		 $o->{'vlist'} eq '' ? 3 : 0;
	my @vopts = map { [ $_->{'value'}, $_->{'value'} ] }
		    sort { $a->{'value'} cmp $b->{'value'} } @views;
	print &ui_table_row($text{'acl_vlist'},
		&ui_radio("vlist_def", $vm,
			  [ [ 1, $text{'acl_vall'} ],
			    [ 0, $text{'acl_vsel'} ],
			    [ 2, $text{'acl_vnsel'} ],
			    [ 3, $text{'acl_vnone'} ] ])."<br>\n".
		&ui_select("vlist", [ split(/\s+/, $o->{'vlist'}) ], \@vopts, 4, 1),
		3);
	}
}

# acl_security_save(&options)
# Parse the form for security options for the bind8 module
sub acl_security_save
{
if ($in{'zones_def'} == 1) {
	$_[0]->{'zones'} = "*";
	}
elsif ($in{'zones_def'} == 2) {
	$_[0]->{'zones'} = join(" ", "!", split(/\0/, $in{'zones'}));
	}
else {
	$_[0]->{'zones'} = join(" ", split(/\0/, $in{'zones'}));
	}
$_[0]->{'inviews'} = !defined($in{'inviews'}) || $in{'inviews_def'} ? "*" :
			join(" ", split(/\0/, $in{'inviews'}));
$_[0]->{'types'} = $in{'types_def'} ? undef : $in{'types'};
$_[0]->{'master'} = $in{'master'} || 0;
$_[0]->{'slave'} = $in{'slave'} || 0;
$_[0]->{'forward'} = $in{'forward'} || 0;
$_[0]->{'delegation'} = $in{'delegation'} || 0;
$_[0]->{'defaults'} = $in{'defaults'};
$_[0]->{'reverse'} = $in{'reverse'};
$_[0]->{'multiple'} = $in{'multiple'};
$_[0]->{'ro'} = $in{'ro'};
$_[0]->{'apply'} = $in{'apply'};
$_[0]->{'dir'} = $in{'dir'};
$_[0]->{'dironly'} = $in{'dironly'};
$_[0]->{'file'} = $in{'file'};
$_[0]->{'params'} = $in{'params'};
$_[0]->{'opts'} = $in{'opts'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'findfree'} = $in{'findfree'};
$_[0]->{'slaves'} = $in{'slaves'};
$_[0]->{'views'} = $in{'views'};
$_[0]->{'remote'} = $in{'remote'};
$_[0]->{'dnssec'} = $in{'dnssec'};
$_[0]->{'gen'} = $in{'gen'};
$_[0]->{'whois'} = $in{'whois'};
$_[0]->{'vlist'} = $in{'vlist_def'} == 1 ? "*" :
		   $in{'vlist_def'} == 3 ? "" :
		   $in{'vlist_def'} == 2 ? join(" ", "!",split(/\0/, $in{'vlist'}))
					 : join(" ", split(/\0/, $in{'vlist'}));
}

