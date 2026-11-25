require 'filemin-lib.pl';

# acl_security_form(&access)
# Output HTML for ACL security form fields
sub acl_security_form
{
my ($access) = @_;

# Directories the user can access, and the warning for root access.
print &ui_table_row(
	$text{'acl_allowed_paths'} .
		&ui_help($text{'acl_allowed_paths_explain'}),
	ui_textarea(
		"allowed_paths",
		join("\n",
			split(/\s+/,
				$access->{'allowed_paths'})),
		4, 80, undef, undef,
		"style='width: 100%'")."<br>\n".
	&ui_page_assets().
	&ui_toggle({ 'name' => 'allow_root_paths',
		     'label' => $text{'acl_root_paths_allow'},
		     'checked' => $access->{'allow_root_paths'},
		     'state' => 'danger' }).
	&ui_alert($text{'acl_root_paths_warn'}, 'danger',
		  [ 'fa-exclamation-triangle', $text{'ui_warning'} ],
		  { 'class' => 'ui_toggle_details' }),
	2);

# Mimetypes allowed to be edited
print &ui_table_row(
	$text{'acl_allowed_for_edit'},
	ui_textarea(
		"allowed_for_edit",
		join("\n",
			split(/\s+/,
				$access->{'allowed_for_edit'})),
		10, 80, undef, undef,
		"style='width: 100%'"),
	2);

# Run as Unix user
print &ui_table_row(
	$text{'acl_work_as'},
	ui_radio_table(
		"user_mode",
		$access->{'work_as_root'} ? 0 :
			$access->{'work_as_user'} ? 2 : 1,
		[ [ 0, $text{'acl_root'} ],
		  [ 1, $text{'acl_same'} ],
		  [ 2, $text{'acl_user'},
		    ui_user_textbox(
			"acl_user",
			$access->{'work_as_user'}) .
		    &ui_br() .
		    &ui_checkbox(
			"acl_user_strict", 1,
			$text{'acl_user_strict'} .
			    &ui_help(
				$text{'acl_user_strict_desc'}),
			$access->{'work_as_user_strict'}) ] ]),
	3);

# Upload max
print &ui_table_row(
	$text{'acl_max'},
	&ui_opt_textbox(
		"max", $access->{'max'}, 10,
		$text{'acl_unlimited'}) .
	" " . $text{'acl_bytes'},
	3);
}

# acl_security_save(&access, &in)
# Parse the ACL security form and save values
sub acl_security_save
{
my ($access, $in) = @_;
local @allowed_paths =
	split(/\s+/, $in->{'allowed_paths'});
if (scalar(@allowed_paths) == 0) {
	&error("No allowed paths defined");
	}
for $path (@allowed_paths) {
	if (!-e $path && $path ne '$HOME' &&
	    $path ne '$ROOT') {
		&error(&text('acl_epath',
			&html_escape($path)));
		}
	}
$access->{'allowed_paths'} =
	join(" ", @allowed_paths);

local @allowed_for_edit =
	split(/\s+/, $in->{'allowed_for_edit'});
if (scalar(@allowed_for_edit) == 0) {
	&error("No mimetypes allowed for ".
		"edit defined");
	}
$access->{'allowed_for_edit'} =
	join(" ", @allowed_for_edit);

if ($in->{'user_mode'} == 0) {
	$access->{'work_as_root'} = 1;
	$access->{'work_as_user'} = undef;
	}
elsif ($in->{'user_mode'} == 1) {
	$access->{'work_as_root'} = 0;
	$access->{'work_as_user'} = undef;
	}
else {
	defined(getpwnam($in->{'acl_user'})) ||
		&error($text{'acl_euser'});
	$access->{'work_as_root'} = 0;
	$access->{'work_as_user'} = $in->{'acl_user'};
	$access->{'work_as_user_strict'} =
		$in->{'acl_user_strict'};
	}

# A group using the login's Unix identity can include root.
my $user = $access->{'work_as_root'} ? 'root' :
	   $access->{'work_as_user'} || $in->{'_acl_user'};
my $uid = defined($user) ? (getpwnam($user))[2] : undef;
if (defined($uid) && $uid == 0 || !$user && $in->{'_acl_group'}) {
	# Resolve $HOME and $ROOT the same way as File Manager at login.
	local %access = %$access;
	local $remote_user = $in->{'_acl_user'} || 'root';
	local $base;
	if (!grep { $_ eq '/' } &get_allowed_paths()) {
		($in->{'allow_root_paths'} || '') eq '1' ||
			&error($text{'acl_eroot_paths'});
		$access->{'allow_root_paths'} = 1;
		}
	}
$access->{'max'} =
	$in->{'max_def'} ? undef : $in{'max'};
}

# acl_security_noconfig()
# Returns 1 to indicate no module config is needed
sub acl_security_noconfig
{
return 1;
}
