require 'sqlite-lib.pl';

# sub acl_security_form(&options)
# Outputs the SQLite module access-control fields from the saved options.
sub acl_security_form
{
my ($o) = @_;
# Show the stored entries as they are, so a $HOME token stays a token
# rather than becoming the editing administrator's own home.
my $paths = join("\n", grep { length($_) }
			  split(/\t+|\r?\n/, $o->{'paths'} // ''));

# Render the path and capability fields.
print &ui_table_row($text{'acl_paths'},
	&ui_textarea("paths", $paths, 8, 70, undef, undef,
		"style='width: 100%'").&ui_help($text{'acl_paths_desc'}), 3);
print &ui_table_row($text{'acl_write'},
	&ui_yesno_radio("write", $o->{'write'}), 3);
print &ui_table_row($text{'acl_create'},
	&ui_yesno_radio("create", $o->{'create'}), 3);
print &ui_table_row($text{'acl_sql'},
	&ui_yesno_radio("sql", $o->{'sql'}), 3);

# Choose which Unix user does the file work: root, the Webmin user's account,
# or a named one. An older ACL shows what the module derives for it.
my $as = &sqlite_work_as_user($o);
my $mode = !defined($as) ? 0 : $o->{'work_as_user'} ? 2 : 1;
print &ui_table_row($text{'acl_work_as'},
	&ui_radio_table("user_mode", $mode, [
		[ 0, $text{'acl_root'} ],
		[ 1, $text{'acl_same'} ],
		[ 2, $text{'acl_user'},
		  &ui_user_textbox("acl_user", $o->{'work_as_user'}) ] ]), 3);
}

# sub acl_security_save(&options, &input)
# Validates the submitted fields and stores them in the options hash.
sub acl_security_save
{
my ($o, $in) = @_;
my @paths = grep { /\S/ } split(/\r?\n/, $in->{'paths'});
@paths || &error($text{'acl_epaths'});
my @resolved;
# Resolve each root so later boundary checks use canonical paths.
foreach my $path (@paths) {
	$path =~ s/^\s+|\s+$//g;
	# $HOME is resolved per user at request time, so it is kept as is.
	if ($path eq '$HOME') {
		push(@resolved, $path);
		next;
		}
	$path =~ /^\// && $path !~ /[\0\t\r\n]/ ||
		&error(&text('acl_epath', &html_escape($path)));
	my $real = &simplify_path(&resolve_links($path));
	defined($real) && -d $real ||
		&error(&text('acl_epath', &html_escape($path)));
	push(@resolved, $real);
	}
# Save unique roots and Boolean capabilities.
$o->{'paths'} = join("\t", &unique(@resolved));
$o->{'write'} = $in->{'write'} ? 1 : 0;
$o->{'create'} = $in->{'create'} ? 1 : 0;
$o->{'sql'} = $in->{'sql'} ? 1 : 0;
# A named Unix user must exist; the other two modes name no user.
if ($in->{'user_mode'} == 2) {
	defined(getpwnam($in->{'acl_user'})) || &error($text{'acl_euser'});
	$o->{'work_as_root'} = 0;
	$o->{'work_as_user'} = $in->{'acl_user'};
	}
else {
	# The root and matching-user modes do not store a named account.
	$o->{'work_as_root'} = $in->{'user_mode'} == 0 ? 1 : 0;
	$o->{'work_as_user'} = '';
	}
}
