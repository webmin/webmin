# Functions for creating simple mail filtering rules
# XXX use same virtualmin spam detection trick for spam module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'aliases-lib.pl';
do 'autoreply-file-lib.pl';

if (&get_product_name() eq 'usermin') {
	# If configured, check if this user has virtualmin spam filtering
	# enabled before switching away from root
	$autoreply_cmd = "$config_directory/forward/autoreply.pl";
	if ($< == 0) {
		if ($config{'virtualmin_spam'} &&
		    -x $config{'virtualmin_spam'}) {
			local $out = &backquote_command(
				"$config{'virtualmin_spam'} $remote_user ".
				"</dev/null 2>/dev/null");
			$out =~ s/\r|\n//g;
			if ($out =~ /\d/) {
				# Yes - we can show the user this
				$global_spamassassin = 2;
				$virtualmin_domain_id = $out;
				}
			}

		# Copy autoreply.pl to /etc/usermin/forward, while we
		# are still root
		local $autoreply_src = "$root_directory/forward/autoreply.pl";
		local @rst = stat($autoreply_src);
		local @cst = stat($autoreply_cmd);
		if (!@cst || $cst[7] != $rst[7]) {
			&copy_source_dest($autoreply_src, $autoreply_cmd);
			&set_ownership_permissions(
				undef, undef, 0755, $autoreply_cmd);
			}

		&switch_to_remote_user();
		}

	&create_user_config_dirs();
	&foreign_require("mailbox");
	}
else {
	# Running under Webmin, so different modules are used
	&foreign_require("mailboxes");
	&foreign_require("usermin");
	$mail_system_module =
		$mailboxes::config{'mail_system'} == 1 ? "postfix" :
		$mailboxes::config{'mail_system'} == 2 ? "qmailadmin" :
							 "sendmail";
	$autoreply_cmd = "$config_directory/$mail_system_module/autoreply.pl";
	$user_autoreply_cmd = "$usermin::config{'usermin_dir'}/forward/autoreply.pl";
	}
&foreign_require("spam");
&foreign_require("procmail");

# list_filters([file])
# Returns a list of filter objects, which have a 1-to-1 correlation with
# procmail recipes. Any recipes too complex for parsing are not included.
sub list_filters
{
local ($file) = @_;
local @rv;
local @pmrc = &procmail::parse_procmail_file($file || $procmail::procmailrc);
foreach my $r (@pmrc) {
	# Check for un-supported recipes
	local @conds = @{$r->{'conds'}};
	if ($r->{'block'} || $r->{'name'}) {
		next;
		}

	# Check for flags
	local %flags = map { $_, 1 } @{$r->{'flags'}};

	# Check for bounce condition
	local $nobounce;
	if (@conds && $conds[0]->[0] eq '!' &&
	    $conds[0]->[1] =~ /FROM_MAILER/) {
		$nobounce = 1;
		shift(@conds);
		}
	next if (@conds > 1);	# Multiple conditions are not supported

	# Work out condition type
	local ($condtype, $cond);
	if (@conds) {
		($condtype, $cond) = @{$conds[0]};
		if ($condtype && $condtype ne "<" && $condtype ne ">") {
			# Unsupported conditon type
			next;
			}
		}

	# Work out action type
	local ($actionspam, $actionreply);
	if ($r->{'type'} eq '|' &&
	    $r->{'action'} =~ /spamassassin|spamc/) {
		$actionspam = 1;
		}
	elsif ($r->{'type'} eq '|' &&
	       ($r->{'action'} =~ /^\Q$autoreply_cmd\E\s+(\S+)/ ||
		$user_autoreply_cmd &&
		$user_autoreply_cmd &&
		  $r->{'action'} =~ /^\Q$user_autoreply_cmd\E\s+(\S+)/)) {
		$actionreply = $1;
		}
	elsif ($r->{'type'} && $r->{'type'} ne '!') {
		# Unsupported action type
		next;
		}

	# Finally create the simple object
	local $simple = { 'condtype' => $condtype,
			  'cond' => $cond,
			  'nocond' => !scalar(@conds),
			  'body' => $flags{'B'},
			  'continue' => $flags{'c'},
			  'actiontype' => $r->{'type'},
			  'action' => $r->{'action'},
			  'nobounce' => $nobounce,
			  'index' => scalar(@rv),
			  'recipe' => $r };

	# Set spam flag
	if ($actionspam) {
		$simple->{'actionspam'} = 1;
		delete($simple->{'actiontype'});
		delete($simple->{'action'});
		}

	# Check for throw away
	if ($simple->{'actiontype'} eq '' &&
	    $simple->{'action'} eq '/dev/null') {
		$simple->{'actionthrow'} = 1;
		delete($simple->{'actiontype'});
		delete($simple->{'action'});
		}

	# Check for default delivery
	if ($simple->{'actiontype'} eq '' &&
	    $simple->{'action'} eq '$DEFAULT') {
		$simple->{'actiondefault'} = 1;
		delete($simple->{'actiontype'});
		delete($simple->{'action'});
		}

	# Read autoreply file
	if ($actionreply) {
		$simple->{'actionreply'} = $actionreply;
		$simple->{'reply'} = { };
		&read_autoreply($actionreply, $simple->{'reply'});
		delete($simple->{'actiontype'});
		delete($simple->{'action'});
		}

	# Split condition regexp into header and value, if possible
	if ($simple->{'condtype'} ne '<' && $simple->{'condtype'} ne '>' &&
	    !$simple->{'body'} &&
	    $simple->{'cond'} =~ /^\^?([a-zA-Z0-9\-]+):\s*(.*)/) {
		local ($h, $v) = ($1, $2);
		if ($h eq "X-Spam-Status" && $v eq "Yes") {
			# Special case for spam detection
			$simple->{'condspam'} = 1;
			}
		elsif ($h eq "X-Spam-Level" && $v =~ /^(\\\*)+$/) {
			# Spam above some level
			$simple->{'condlevel'} = length($v)/2;
			}
		else {
			# Match on some header
			$simple->{'condheader'} = $h;
			$simple->{'condvalue'} = $v;
			}
		delete($simple->{'cond'});
		}

	push(@rv, $simple);
	}
return @rv;
}

# create_filter(&filter)
# Create a new filter by adding a procmail recipe
sub create_filter
{
local ($filter) = @_;
local $recipe = { };
&update_filter_recipe($filter, $recipe);
&procmail::create_recipe($recipe);
&setup_forward_procmail();
}

# modify_filter(&filter)
# Change a filter by modifying the underlying procmail recipe
sub modify_filter
{
local ($filter) = @_;
&update_filter_recipe($filter, $filter->{'recipe'});
&procmail::modify_recipe($filter->{'recipe'});
&setup_forward_procmail();
}

# insert_filter(&filter)
# Like create_filter, but adds to the top of the .procmailrc
sub insert_filter
{
local ($filter) = @_;
local $recipe = { };
&update_filter_recipe($filter, $recipe);
local @pmrc = &procmail::parse_procmail_file(
	$filter->{'file'} || $procmail::procmailrc);
if (@pmrc) {
	&procmail::create_recipe_before($recipe, $pmrc[0]);
	}
else {
	&procmail::create_recipe($recipe);
	}
&setup_forward_procmail();
}

# update_filter_recipe(&filter, &recipe)
# Update a procmail recipe based on some filter
sub update_filter_recipe
{
local ($filter, $recipe) = @_;

# Set condition section
local @conds;
local @flags;
if ($filter->{'condspam'}) {
	@conds = ( [ "", "X-Spam-Status: Yes" ] );
	}
elsif ($filter->{'condlevel'}) {
	local $stars = join("", map { "\\*" } (1..$filter->{'condlevel'}));
	@conds = ( [ "", "^"."X-Spam-Level: $stars" ] );
	}
elsif ($filter->{'condheader'}) {
	@conds = ( [ "", "^".$filter->{'condheader'}.": ".
			 $filter->{'condvalue'} ] );
	}
elsif ($filter->{'condtype'} eq '<' || $filter->{'condtype'} eq '>') {
	@conds = ( [ $filter->{'condtype'}, $filter->{'cond'} ] );
	}
elsif ($filter->{'cond'}) {
	@conds = ( [ "", $filter->{'cond'} ] );
	}

# Set action section
if ($filter->{'actionspam'}) {
	$recipe->{'type'} = '|';
	$recipe->{'action'} = &spam::get_procmail_command();
	push(@flags, "f", "w");
	}
elsif ($filter->{'actionthrow'}) {
	$recipe->{'type'} = '';
	$recipe->{'action'} = '/dev/null';
	}
elsif ($filter->{'actiondefault'}) {
	$recipe->{'type'} = '';
	$recipe->{'action'} = '$DEFAULT';
	}
elsif ($filter->{'actionreply'}) {
	$recipe->{'type'} = '|';
	$recipe->{'action'} =
		"$autoreply_cmd $filter->{'reply'}->{'autoreply'} $remote_user";
	&write_autoreply($filter->{'reply'}->{'autoreply'},
			 $filter->{'reply'});
	}
else {
	$recipe->{'type'} = $filter->{'actiontype'};
	$recipe->{'action'} = $filter->{'action'};
	local $folder = &file_to_folder($filter->{'action'}, [ ], undef, 1);
	if ($recipe->{'type'} eq '' && $folder->{'type'} == 1) {
		# Enable locking for file delivery
		$recipe->{'lockfile'} ||= "";
		}
	if ($filter->{'actiontype'} eq '!' && $filter->{'nobounce'}) {
		# Add condition to suppress forwarding of bounces
		unshift(@conds, [ '!', '^FROM_MAILER' ]);
		}
	}
$recipe->{'conds'} = \@conds;

# Set flags
push(@flags, "B") if ($filter->{'body'});
push(@flags, "c") if ($filter->{'continue'});
$recipe->{'flags'} = [ &unique(@flags) ];
}

# delete_filter(&filter)
# Delete a filter by removing the underlying procmail rule
sub delete_filter
{
local ($filter) = @_;
&procmail::delete_recipe($filter->{'recipe'});
&setup_forward_procmail();
if ($filter->{'actionreply'} && !-d $filter->{'actionreply'}) {
	&unlink_file($filter->{'actionreply'});
	}
}

# swap_filters(&filter1, &filter2)
# Swap two filters in the config file
sub swap_filters
{
local ($filter1, $filter2) = @_;
&procmail::swap_recipes($filter1->{'recipe'}, $filter2->{'recipe'});
&setup_forward_procmail();
}

# file_to_folder(file, &folders, [homedir], [fake-if-missing])
# Given a path like mail/foo or ~/mail/foo or $HOME/mail/foo or
# /home/bob/mail/foo, returns the folder object for it.
sub file_to_folder
{
local ($file, $folders, $home, $fake) = @_;
$home ||= $remote_user_info[7];
$file =~ s/^\~/$home/;
$file =~ s/^\$HOME/$home/;
if ($file !~ /^\//) {
	$file = "$home/$file";
	}
local ($folder) = grep { $_->{'file'} eq $file ||
			 $_->{'file'}.'/' eq $file } @$folders;
if (!$folder && $fake) {
	# Create a fake folder object to match
	$folder = { 'file' => $file,
		    'type' => 1,
		    'fake' => 1 };
	if ($folder->{'file'} =~ s/\/$//) {
		$folder->{'type'} = 2;
		}
	$folder->{'file'} =~ /\/\.?([^\/]+)$/;
	$folder->{'name'} = $1;
	if (lc($folder->{'name'}) eq 'spam') {
		$folder->{'spam'} = 1;
		$folder->{'name'} = "Spam";
		}
	}
return $folder;
}

# get_global_spamassassin()
# Returns true if spamasassin is run globally
sub get_global_spamassassin
{
return $global_spamassassin if ($global_spamassassin);
local @recipes = &procmail::parse_procmail_file(
	$spam::config{'global_procmailrc'});
return &spam::find_spam_recipe(\@recipes) ? 1 : 0;
}

# get_global_spam_path()
# Returns the global path to which spam is delivered, typically by a 
# Virtualmin per-domain procmail file
sub get_global_spam_path
{
if ($virtualmin_domain_id) {
	# Read the Virtualmin procmailrc for the domain
	local $vmpmrc = "$config{'virtualmin_config'}/procmail/".
		        $virtualmin_domain_id;
	local @vmrecipes = &procmail::parse_procmail_file($vmpmrc);
	local $spamrec = &spam::find_file_recipe(\@vmrecipes);
	if ($spamrec) {
		return $spamrec->{'action'};
		}
	}
# Also check the global /etc/procmailrc
local @recipes = &procmail::parse_procmail_file(
	$spam::config{'global_procmailrc'});
local $spamrec = &spam::find_file_recipe(\@recipes);
if ($spamrec) {
	return $spamrec->{'action'};
	}
else {
	return undef;
	}
}

# get_global_spam_delete()
# Returns the global score above which spam is deleted, typically by a 
# Virtualmin per-domain procmail file
sub get_global_spam_delete
{
if ($virtualmin_domain_id) {
	# Read the Virtualmin procmailrc for the domain
	local $vmpmrc = "$config{'virtualmin_config'}/procmail/".
		        $virtualmin_domain_id;
	local @vmrecipes = &procmail::parse_procmail_file($vmpmrc);
	local ($spamrec, $level) = &spam::find_delete_recipe(\@vmrecipes);
	if ($spamrec) {
		return $level;
		}
	}
# Also check the global /etc/procmailrc
local @recipes = &procmail::parse_procmail_file(
	$spam::config{'global_procmailrc'});
local ($spamrec, $level) = &spam::find_delete_recipe(\@recipes);
if ($spamrec) {
	return $level;
	}
else {
	return undef;
	}
}

sub has_spamassassin
{
return &foreign_installed("spam");
}

# get_override_alias()
# Check for any mail alias matching this user, which is defined in /etc/aliases
# as an entry matching his username.
sub get_override_alias
{
local @afiles = split(/\t+/, $config{'alias_files'});
foreach my $alias (&list_aliases(\@afiles)) {
	if ($alias->{'name'} eq $remote_user && $alias->{'enabled'}) {
		return $alias;
		}
	}
return undef;
}

# describe_alias_dest(&values)
# Returns a text description of some alias destination
sub describe_alias_dest
{
local ($values) = @_;
local @rv;
foreach my $v (@$values) {
	local ($atype, $adesc) = &alias_type($v);
	if ($atype == 1 && $adesc eq "\\$remote_user") {
		push(@rv, $text{'aliases_your'});
		}
	elsif ($atype == 1 && $adesc =~ /^\\(\S+)$/) {
		push(@rv, &text('aliases_other', "<tt>$1</tt>"));
		}
	elsif ($atype == 3 && $adesc eq "/dev/null") {
		push(@rv, $text{'aliases_delete'});
		}
	elsif ($atype == 4 && $adesc =~ /^(.*)\/autoreply.pl\s+(\S+)/) {
		# Autoreply from file .. check contents
		local $auto = &read_file_contents("$2");
		if ($auto) {
			local @lines = grep { !/^(\S+):/} split(/\r?\n/, $auto);
			local $msg = join(" ", @lines);
			$msg = substr($msg, 0, 100)." ..."
				if (length($msg) > 100);
			push(@rv, &text('aliases_auto', "<i>$msg</i>"));
			}
		else {
			push(@rv, &text('aliases_type5', "<tt>$2</tt>"));
			}
		}
	elsif ($atype == 4 && $adesc =~ /^(.*)\/filter.pl\s+(\S+)/) {
		# Apply filter file
		push(@rv, &text('aliases_type6', "<tt>$2</tt>"));
		}
	else {
		push(@rv, &text('aliases_type'.$atype, $adesc));
		}
	}
return @rv;
}

# is_table_comment(line, [force-prefix])
# Returns the comment text if a line contains a comment, like # foo. This is
# defined only because functions in aliases-lib.pl call it.
sub is_table_comment
{
local ($line, $force) = @_;
if ($force) {
	return $line =~ /^\s*#+\s*Webmin:\s*(.*)/ ? $1 : undef;
	}
else {
	return $line =~ /^\s*#+\s*(.*)/ ? $1 : undef;
	}
}

# describe_condition(&filter)
# Returns a human-readable description of the filter condition, and a flag
# indicating if this is an 'always' condition.
sub describe_condition
{
local ($f) = @_;
local $cond;
local $lastalways = 0;
if ($f->{'condspam'}) {
	$cond = $text{'index_cspam'};
	}
elsif ($f->{'condlevel'}) {
	$cond = &text('index_clevel', $f->{'condlevel'});
	}
elsif ($f->{'condheader'}) {
	if ($f->{'condvalue'} =~ /^\.\*(.*)\$$/) {
		$cond = &text('index_cheader2',
			"<tt>".&html_escape($f->{'condheader'})."</tt>",
			"<tt>".&html_escape(&prettify_regexp("$1"))."</tt>");
		}
	elsif ($f->{'condvalue'} =~ /^\.\*(.*)\.\*$/ ||
	       $f->{'condvalue'} =~ /^\.\*(.*)$/) {
		$cond = &text('index_cheader1',
			"<tt>".&html_escape($f->{'condheader'})."</tt>",
			"<tt>".&html_escape(&prettify_regexp("$1"))."</tt>");
		}
	elsif ($f->{'condvalue'} =~ /^(.*)\.\*$/ ||
	       $f->{'condvalue'} =~ /^(.*)$/) {
		$cond = &text('index_cheader0',
			"<tt>".&html_escape($f->{'condheader'})."</tt>",
			"<tt>".&html_escape(&prettify_regexp("$1"))."</tt>");
		}
	}
elsif ($f->{'condtype'} eq '<' || $f->{'condtype'} eq '>') {
	$cond = &text('index_csize'.$f->{'condtype'},
		      &nice_size($f->{'cond'}));
	}
elsif ($f->{'cond'}) {
	$cond = &text($f->{'body'} ? 'index_cre2' : 'index_cre',
		       "<tt>".&html_escape($f->{'cond'})."</tt>");
	}
else {
	$cond = $text{'index_calways'};
	if (!$f->{'continue'} && !$f->{'actionspam'}) {
		$lastalways = 1;
		}
	}
return wantarray ? ( $cond, $lastalways ) : $cond;
}

# prettify_regexp(string)
# If a string contains only \ quoted special characters, remove the \s
# Also, undo any mimewords encoding.
sub prettify_regexp
{
my ($str) = @_;
my $re = $str;
$re =~ s/\\./x/g;
if ($re =~ /^[a-zA-Z0-9_ ]*$/) {
	$str =~ s/\\(.)/$1/g;
	}
if (&get_product_name() eq "webmin") {
	&foreign_require("mailboxes");
	return &mailboxes::decode_mimewords($str);
	}
elsif (&get_product_name() eq "usermin") {
	&foreign_require("mailbox");
	return &mailbox::decode_mimewords($str);
	}
else {
	return $str;
	}
}

# describe_action(&filter, &folder, [homedir])
# Returns a human-readable description for the delivery action for some folder
sub describe_action
{
local ($f, $folders, $home) = @_;
local $action;
if ($f->{'actionspam'}) {
	$action = $text{'index_aspam'};
	}
elsif ($f->{'actionthrow'}) {
	$action = $text{'index_athrow'};
	}
elsif ($f->{'actiondefault'}) {
	$action = $text{'index_adefault'};
	}
elsif ($f->{'actiontype'} eq '!') {
	$action = &text('index_aforward',
		"<tt>".&html_escape($f->{'action'})."</tt>");
	}
elsif ($f->{'actionreply'}) {
	$action = &text('index_areply',
	    "<i>".&html_escape(substr(
		$f->{'reply'}->{'autotext'}, 0, 50))."</i>");
	}
else {
	# Work out what folder
	local $folder = &file_to_folder($f->{'action'}, $folders, $home);
	if ($folder) {
		if (&get_product_name() eq 'usermin') {
			local $id = &mailbox::folder_name($folder);
			$action = &text('index_afolder',
			   "<a href='../mailbox/index.cgi?id=$id'>".
			   "$folder->{'name'}</a>");
			}
		else {
			local $id = &mailboxes::folder_name($folder);
			if (&foreign_available("mailboxes")) {
				$action = &text('index_afolder',
				  "<a href='../mailboxes/list_mail.cgi?user=".
				  &urlize($folder->{'user'})."&folder=".
				  $folder->{'index'}."'>$folder->{'name'}</a>");
				}
			else {
				$action = &text('index_afolder',
						$folder->{'name'});
				}
			}
		}
	else {
		$action = &text('index_afile',
				"<tt>$f->{'action'}</tt>");
		}
	}
if ($f->{'continue'}) {
	$action = &text('index_acontinue', $action);
	}
return $action;
}

# can_simple_autoreply()
# Returns 1 if the current filter rules are simple enough to allow an autoreply
# to be added or removed. 
sub can_simple_autoreply
{
return 1;	# Always true for now
}

# can_simple_forward()
# Returns 1 if the current filter rules are simple enough to allow a mail
# forwarder to be added or removed
sub can_simple_forward
{
return 1;	# Always can for now
}

# no_user_procmailrc()
# Returns 1 if /etc/procmailrc has a recipe to always deliver to the user's
# mailbox, which prevents this module from configuring anything useful
sub no_user_procmailrc
{
local %sconfig = &foreign_config("spam");
local @recipes = &procmail::parse_procmail_file(
	$sconfig{'global_procmailrc'});
local ($force) = grep { $_->{'action'} eq '$DEFAULT' &&
			!@{$_->{'conds'}} } @recipes;
return $force;
}

# setup_forward_procmail()
# If configured, create a .forward file that runs procmail (if not setup yet)
sub setup_forward_procmail
{
return 0 if (!$config{'forward_procmail'});
return 0 if (!$module_info{'usermin'});
local $fwdfile = "$remote_user_info[7]/.forward";
local $procmail = &has_command("procmail");
return 0 if (!$procmail);
local $lref = &read_file_lines($fwdfile);
local $found;
foreach my $l (@$lref) {
	if ($l =~ /\Q$procmail\E/) {
		$found++;
		}
	}
if ($found) {
	&unflush_file_lines($fwdfile);
	}
else {
	# Add procmail call
	push(@$lref, "|$procmail");
	&flush_file_lines($fwdfile);
	}
}

1;

