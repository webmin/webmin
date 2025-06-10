#!/usr/local/bin/perl
# Create, update or delete a filter

require './filter-lib.pl';
use Time::Local;
&ReadParse();

# Find existing filter object
@filters = &list_filters();
if (!$in{'new'}) {
	($filter) = grep { $_->{'index'} == $in{'idx'} } @filters;
	$filter || &error($text{'save_egone'});
	}
else {
	$filter = { 'index' => scalar(@filters) };
	}

if ($in{'delete'}) {
	# Just remove
	&lock_file($procmail::procmailrc);
	&delete_filter($filter);
	&unlock_file($procmail::procmailrc);
	&redirect("");
	}
elsif ($in{'apply'}) {
	# Redirect to mail search, with keys from filter
	if ($filter->{'condspam'}) {
		# Is spam or not?
		&redirect("../mailbox/mail_search.cgi?".
			  "id=".&urlize($in{'applyfrom'})."&".
			  "field_0=X-Spam-Status&".
			  "what_0=Yes");
		}
	elsif ($filter->{'condlevel'}) {
		# Spam level at least
		&redirect("../mailbox/mail_search.cgi?".
			  "id=".&urlize($in{'applyfrom'})."&".
			  "spam=1&score=".$filter->{'condlevel'});
		}
	else {
		# Some other header
		$field = $filter->{'condheader'};
		$what = $filter->{'condvalue'};
		$field = lc($field);
		# XXX regexp checkbox?
		&redirect("../mailbox/mail_search.cgi?".
			  "id=".&urlize($in{'applyfrom'})."&".
			  "field_0=".&urlize($field)."&".
			  "what_0=".&urlize($what)."&".
			  "re_0=1");
		}
	}
elsif ($in{'move'}) {
	# Redirect to move CGI
	&redirect("move.cgi?idx=$in{'idx'}");
	}
else {
	# Validate and store inputs
	&error_setup($text{'save_err'});

	# Parse condition first
	delete($filter->{'condspam'});
	delete($filter->{'condlevel'});
	delete($filter->{'condheader'});
	delete($filter->{'condtype'});
	delete($filter->{'cond'});
	$filter->{'body'} = 0;
	if ($in{'cmode'} == 0) {
		# Always enabled, so nothing to set!
		}
	elsif ($in{'cmode'} == 5) {
		# Match if spamassassin has set header
		$filter->{'condspam'} = 1;
		}
	elsif ($in{'cmode'} == 6) {
		# Match by spam level
		$in{'condlevel'} =~ /^[1-9]\d*$/ ||
			&error($text{'save_econdlevel'});
		$filter->{'condlevel'} = $in{'condlevel'};
		}
	elsif ($in{'cmode'} == 4) {
		# Check some header
		$filter->{'condheader'} = $in{'condmenu'} || $in{'condheader'};
		$filter->{'condheader'} =~ /^[a-zA-Z0-9\-]+$/ ||
			&error($text{'save_econdheader'});
		if ($in{'condvalue'} !~ /^[\000-\177]*$/) {
			$in{'condvalue'} = &mailbox::encode_mimewords(
				$in{'condvalue'}, 'Charset' => &get_charset());
			}
		if (!$in{'condregexp'} &&
		    $in{'condvalue'} =~ /[\^\$\.\*\+\?\|\(\)\[\]\{\}\\]/) {
			# If the user didn't ask for a regexp but there are
			# regexp special characters, escape them
			$in{'condvalue'} = quotemeta($in{'condvalue'});
			}
		if ($in{'condmode'} == 0) {
			$filter->{'condvalue'} = $in{'condvalue'};
			}
		elsif ($in{'condmode'} == 1) {
			$filter->{'condvalue'} = ".*".$in{'condvalue'}.".*";
			}
		else {
			$filter->{'condvalue'} = ".*".$in{'condvalue'}."\$";
			}
		}
	elsif ($in{'cmode'} == 3) {
		# Smaller than some size
		$in{'condsmall'} =~ /^\d+$/ || &error($text{'save_esmall'});
		$filter->{'cond'} = $in{'condsmall'}*$in{'condsmall_units'};
		$filter->{'condtype'} = '<';
		}
	elsif ($in{'cmode'} == 2) {
		# Larger than some size
		$in{'condlarge'} =~ /^\d+$/ || &error($text{'save_elarge'});
		$filter->{'cond'} = $in{'condlarge'}*$in{'condlarge_units'};
		$filter->{'condtype'} = '>';
		}
	elsif ($in{'cmode'} == 1) {
		# Matches regexp
		$in{'cond'} || &error($text{'save_econd'});
		$filter->{'cond'} = $in{'cond'};
		$filter->{'body'} = $in{'body'};
		}

	# Parse action section
	delete($filter->{'actionreply'});
	delete($filter->{'actionspam'});
	delete($filter->{'actionthrow'});
	delete($filter->{'actiondefault'});
	delete($filter->{'actionreply'});
	delete($filter->{'actiontype'});
	delete($filter->{'continue'});
	if ($in{'amode'} == 3) {
		# Deliver normally
		$filter->{'actiondefault'} = 1;
		}
	elsif ($in{'amode'} == 5) {
		# Run spamassassin
		$filter->{'actionspam'} = 1;
		}
	elsif ($in{'amode'} == 4) {
		# Throw away
		$filter->{'actionthrow'} = 1;
		}
	elsif ($in{'amode'} == 1) {
		# Forward to an address
		$in{'forward'} =~ /\S/ || &error($text{'save_eforward'});
		$in{'forward'} =~ s/^\s+//;
		$in{'forward'} =~ s/\s+$//;
		$in{'forward'} =~ s/\s+/,/g;
		$filter->{'action'} = $in{'forward'};
		$filter->{'actiontype'} = '!';
		$filter->{'nobounce'} = $in{'nobounce'};
		}
	elsif ($in{'amode'} == 0) {
		# Write to a folder or file
		@folders = &mailbox::list_folders();
		if ($in{'folder'}) {
			$folder = &mailbox::find_named_folder($in{'folder'},
							      \@folders);
			$file = $folder->{'file'};
			}
		else {
			$in{'file'} =~ /\S/ || &error($text{'save_efile'});
			$file = $in{'file'};
			}
		$file =~ s/^\Q$remote_user_info[7]\/\E/\$HOME\//;
		$filter->{'action'} = $file;
		if ($folder->{'type'} == 1 ||
		    $folder->{'type'} == 4 && -d $folder->{'file'}) {
			# Maildir has to end with /
			$filter->{'action'} .= '/';
			}
		}
	elsif ($in{'amode'} == 6) {
		# Send autoreply
		$filter->{'actionreply'} = 1;
		$in{'reply'} =~ /\S/ || &error($text{'save_ereply'});
		$in{'reply'} =~ s/\r//g;
		$filter->{'reply'}->{'autotext'} = $in{'reply'};
		$filter->{'reply'}->{'from'} =
			&mailbox::get_preferred_from_address();
		$idx = defined($filter->{'index'}) ? $filter->{'index'}
						   : scalar(@filters);
		$filter->{'reply'}->{'autoreply'} ||=
			"$remote_user_info[7]/autoreply.$idx.txt";
		if ($config{'reply_force'}) {
			# Forced to minimum
			$min = $config{'reply_min'} || 60;
			$filter->{'reply'}->{'period'} = $min*60;
			$filter->{'reply'}->{'replies'} ||=
				"$user_module_config_directory/replies";
			}
		elsif ($in{'period_def'}) {
			# No autoreply period
			delete($filter->{'reply'}->{'replies'});
			delete($filter->{'reply'}->{'period'});
			}
		else {
			# Set reply period and tracking file
			$in{'period'} =~ /^\d+$/ ||
				&error($text{'save_eperiod'});
			if ($config{'reply_min'} &&
			    $in{'period'} < $config{'reply_min'}) {
				&error(&text('save_eperiodmin',
					     $config{'reply_min'}));
				}
			$filter->{'reply'}->{'period'} = $in{'period'}*60;
			$filter->{'reply'}->{'replies'} ||=
				"$user_module_config_directory/replies";
			}
		# Save autoreply start and end
		foreach $p ('start', 'end') {
			local ($s, $m, $h) = $p eq 'start' ? (0, 0, 0) :
						(59, 59, 23);
			if ($in{'d'.$p}) {
				eval {
					$tm = timelocal($s, $m, $h, $in{'d'.$p},
					    $in{'m'.$p}-1, $in{'y'.$p}-1900);
					};
				$tm || &error($text{'save_e'.$p});
				$filter->{'reply'}->{'autoreply_'.$p} = $tm;
				}
			else {
				delete($filter->{'reply'}->{'autoreply_'.$p});
				}
			}
		# Save character set
		if ($in{'charset_def'}) {
			delete($filter->{'reply'}->{'charset'});
			}
		else {
			$in{'charset'} =~ /^[a-z0-9\.\-\_]+$/i ||
				error($text{'save_echarset'});
			$filter->{'reply'}->{'charset'} = $in{'charset'};
			}
		# Save subject
		if ($in{'subject_def'}) {
			delete($filter->{'reply'}->{'subject'});
			}
		else {
			$filter->{'reply'}->{'subject'} = $in{'subject'};
			}
		}
	elsif ($in{'amode'} == 7) {
		# Create a new folder for saving (always in Maildir format)
		$in{'newfolder'} =~ /\S/ || &error($text{'save_enewfolder'});
		$in{'newfolder'} !~ /^\// && $in{'newfolder'} !~ /\.\./ ||
			&error($text{'save_enewfolder2'});
		($clash) = grep { $_->{'name'} eq $in{'newfolder'} } 
				@folders;
		$clash && &error($text{'save_enewfolder3'});
		$folder = { 'name' => $in{'newfolder'},
			    'mode' => 0,
			    'type' => 1 };
		&mailbox::save_folder($folder);
		$filter->{'action'} = $folder->{'file'}."/";
		$filter->{'action'} =~ s/^\Q$remote_user_info[7]\/\E/\$HOME\//;
		}
	$filter->{'continue'} = $in{'continue'};

	# Save or create
	&lock_file($procmail::procmailrc);
	if ($in{'new'}) {
		&create_filter($filter);
		}
	else {
		&modify_filter($filter);
		}
	&unlock_file($procmail::procmailrc);
	&redirect("");
	}
