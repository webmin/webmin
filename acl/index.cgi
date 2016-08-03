#!/usr/local/bin/perl
# index.cgi
# List all webmin users

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Fetch user and group lists, if possible
my (@ulist, @glist, %ingroup);
eval {
	$main::error_must_die = 1;
	@glist = &list_groups();
	foreach my $g (@glist) {
		foreach my $gm (@{$g->{'members'}}) {
			$ingroup{$gm} = $g;
			}
		}
	@ulist = &list_users();
	};
if ($@) {
	print "<b>",&text('index_eulist', "$@"),"</b><p>\n";
	}

my $me;
foreach my $u (@ulist) {
	$me = $u if ($u->{'name'} eq $base_remote_user);
	}
my @mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
	   $access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
			          &list_modules();
my %mcan = map { $_, 1 } @mcan;

if ($config{'order'}) {
	@ulist = sort { $a->{'name'} cmp $b->{'name'} } @ulist;
	@glist = sort { $a->{'name'} cmp $b->{'name'} } @glist;
	}

my %modname;
foreach my $m (&list_module_infos()) {
	$modname{$m->{'dir'}} = $m->{'desc'};
	}
my @canulist = grep { &can_edit_user($_->{'name'}, \@glist) } @ulist;
my ($form, $shown_users);
my @gbut = @glist ? ( undef, [ 'joingroup', $text{'index_joingroup'},
		&ui_select("group", undef, [ map { $_->{'name'} } @glist ]) ] )
		  : ( );
if (!@canulist) {
	# If no users, only show section heading if can create
	if ($access{'create'}) {
		print &ui_subheading($text{'index_users'})
			if (!$config{'display'});
		print "<b>$text{'index_nousers'}</b><p>\n";
		print ui_link("edit_user.cgi", $text{'index_create'}) . "\n";
		$shown_users = 1;
		}
	}
elsif ($config{'display'}) {
	# Show as table of names
	print &ui_subheading($text{'index_users'});
	print &ui_form_start("delete_users.cgi", "post");
	&show_name_table(\@canulist, "edit_user.cgi",
			 $access{'create'} ? $text{'index_create'} : undef,
			 $text{'index_users'}, "user");
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     @gbut ]);
	$shown_users = 1;
	$form++;
	}
else {
	# Show usernames and modules
	print &ui_subheading($text{'index_users'});
	my @rowlinks = ( );
	print &ui_form_start("delete_users.cgi", "post");
	push(@rowlinks, &select_all_link("d", $form),
		     &select_invert_link("d", $form));
	push(@rowlinks, ui_link("edit_user.cgi", $text{'index_create'}))
		if ($access{'create'});
	print &ui_links_row(\@rowlinks);

	print &ui_columns_start([ $text{'index_user'},
				  $text{'index_modules'} ], 100);
	foreach my $u (@canulist) {
		my $smods;
		if ($ingroup{$u->{'name'}}) {
			# Is a member of a group
			$smods = &show_modules(
			      "user", $u->{'name'}, $u->{'ownmods'}, 0,
			      &text('index_modgroups',
				  "<tt>$ingroup{$u->{'name'}}->{'name'}</tt>"));
				      
			}
		else {
			# Is a stand-alone user
			$smods = &show_modules(
			      "user", $u->{'name'}, $u->{'modules'}, 1);
			}
		print &ui_columns_row([ &user_link($u, "edit_user.cgi", "user"),
					$smods ], [ "valign=top" ]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     @gbut ]);
	$shown_users = 1;
	$form++;
	}
print "<p>\n";

if ($shown_users && $access{'groups'}) {
	print &ui_hr();
	}

if ($access{'groups'}) {
	print &ui_subheading($text{'index_groups'});
	if (!@glist) {
		# No groups, so just show create link
		print "<b>$text{'index_nogroups'}</b><p>\n";
		print ui_link("edit_group.cgi", $text{'index_gcreate'}) . "<p>\n";
		}
	elsif ($config{'display'}) {
		# Show just group names
		print &ui_form_start("delete_groups.cgi", "post");
		&show_name_table(\@glist, "edit_group.cgi",
				 $text{'index_gcreate'},
				 $text{'index_groups'}, "group");
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		$form++;
		}
	else {
		# Show table of groups
		my @rowlinks = ( );
		print &ui_form_start("delete_groups.cgi", "post");
		push(@rowlinks, &select_all_link("d", $form),
			     &select_invert_link("d", $form));
		push(@rowlinks,
		     ui_link("edit_group.cgi", $text{'index_gcreate'}));
		print &ui_links_row(\@rowlinks);

		print &ui_columns_start([ $text{'index_group'},
					  $text{'index_members'},
					  $text{'index_modules'} ], 100);
		foreach my $g (@glist) {
			my @cols;
			push(@cols, &user_link($g,"edit_group.cgi","group"));
			push(@cols, join(" ", @{$g->{'members'}}));
			if ($ingroup{'@'.$g->{'name'}}) {
				# Is a member of some other group
				push(@cols, &show_modules("group", $g->{'name'},
				    $g->{'ownmods'},0,
				    &text('index_modgroups',
					  "<tt>$ingroup{$g->{'name'}}->{'name'}</tt>")));
				}
			else {
				# Is a top-level group
				push(@cols, &show_modules("group", $g->{'name'},
					      $g->{'modules'}, 1));
				}
			print &ui_columns_row(\@cols);
			}
		print &ui_columns_end();
		print &ui_links_row(\@rowlinks);
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		$form++;
		}
	}

my %miniserv;
my (@icons, @links, @titles);
&get_miniserv_config(\%miniserv);
if ($access{'sync'} && &foreign_check("useradmin")) {
	push(@icons, "images/convert.gif");
	push(@links, "convert_form.cgi");
	push(@titles, $text{'index_convert'});
	}
if ($access{'sync'} && $access{'create'} && $access{'delete'}) {
	push(@icons, "images/sync.gif");
	push(@links, "edit_sync.cgi");
	push(@titles, $text{'index_sync'});
	}
if ($access{'unix'} && $access{'create'} && $access{'delete'}) {
	push(@icons, "images/unix.gif");
	push(@links, "edit_unix.cgi");
	push(@titles, $text{'index_unix'});
	}
if ($access{'sessions'} && $miniserv{'session'}) {
	push(@icons, "images/sessions.gif");
	push(@links, "list_sessions.cgi");
	push(@titles, $text{'index_sessions'});
	}
if (uc($ENV{'HTTPS'}) eq "ON" && $miniserv{'ca'}) {
	push(@icons, "images/cert.gif");
	push(@links, "cert_form.cgi");
	push(@titles, $text{'index_cert'});
	}
push(@icons, "images/twofactor.gif");
push(@links, "twofactor_form.cgi");
push(@titles, $text{'index_twofactor'});
if ($access{'rbacenable'}) {
	push(@icons, "images/rbac.gif");
	push(@links, "edit_rbac.cgi");
	push(@titles, $text{'index_rbac'});
	}
if ($access{'pass'}) {
	push(@icons, "images/pass.gif");
	push(@links, "edit_pass.cgi");
	push(@titles, $text{'pass_title'});
	}
if ($access{'sql'}) {
	push(@icons, "images/sql.gif");
	push(@links, "edit_sql.cgi");
	push(@titles, $text{'sql_title'});
	}

if (@icons) {
	print &ui_hr();
	&icons_table(\@links, \@titles, \@icons);
	}

&ui_print_footer("/", $text{'index'});

# show_modules(type, who, &mods, show-global, prefix)
sub show_modules
{
my ($type, $who, $mods, $global, $prefix) = @_;
$mods ||= [ ];
my $rv;
$rv .= $prefix."<br>\n" if ($prefix);
my @grid;
foreach my $m (sort { $modname{$a} cmp $modname{$b} } @$mods) {
	if ($modname{$m}) {
		if ($mcan{$m} && $access{'acl'}) {
			push(@grid, ui_link("edit_acl.cgi?mod=" .
			      &urlize($m)."&$type=".&urlize($who),
			      $modname{$m}));
			}
		else {
			push(@grid, $modname{$m});
			}
		}
	}
$rv .= &ui_grid_table(\@grid, 3, 100,
	[ "width=33%", "width=33%", "width=33%" ]);
return $rv;
}

# show_name_table(&users|&groups, cgi, create-text, header-text, param)
sub show_name_table
{
# Show table of users, and maybe create links
my @rowlinks = ( &select_all_link("d", $form),
		 &select_invert_link("d", $form) );
push(@rowlinks, ui_link("$_[1]", $_[2])) if ($_[2]);
print &ui_links_row(\@rowlinks);
my @links;
for(my $i=0; $i<@{$_[0]}; $i++) {
	push(@links, &user_link($_[0]->[$i], $_[1], $_[4]));
	}
print &ui_grid_table(\@links, 4, 100,
	[ "width=25%", "width=25%", "width=25%", "width=25%" ], undef, $_[3]);
print &ui_links_row(\@rowlinks);
}

# user_link(user, cgi, param)
sub user_link
{
my $lck = $_[0]->{'pass'} =~ /^\!/ ? 1 : 0;
my $ro = $_[0]->{'readonly'};
return &ui_checkbox("d", $_[0]->{'name'}, "", 0).
       ($lck ? "<i>" : "").
       ($ro ? "<b>" : "").
       ui_link("$_[1]?$_[2]=".&urlize($_[0]->{'name'}),
	           $_[0]->{'name'}).
       ($_[0]->{'twofactor_id'} ? "*" : "").
       ($ro ? "</b>" : "").
       ($lck ? "</i>" : "");
}

