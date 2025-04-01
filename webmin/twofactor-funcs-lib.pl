# Functions for two-factor enrollment and verification

# list_twofactor_providers()
# Returns a list of all supported providers, each of which is an array ref
# containing an ID, name and URL for more info
sub list_twofactor_providers
{
return ( [ 'totp', $text{'twofactor_totp'},
	   'https://en.wikipedia.org/wiki/Time-based_one-time_password' ],
	 [ 'authy', 'Authy',
	   'http://www.authy.com/' ] );
}

# show_twofactor_apikey_authy(&miniserv)
# Returns HTML for the form for authy-specific provider inputs
sub show_twofactor_apikey_authy
{
my ($miniserv) = @_;
my $rv;
$rv .= ui_table_row($text{'twofactor_apikey'},
	ui_textbox("authy_apikey", $miniserv->{'twofactor_apikey'}, 40));
return $rv;
}

# validate_twofactor_apikey_authy(&in, &miniserv)
# Validates inputs from show_twofactor_apikey_authy, and stores them. Returns
# undef if OK, or an error message on failure
sub validate_twofactor_apikey_authy
{
my ($in, $miniserv) = @_;
my $key = $in->{'authy_apikey'};
my $test = $miniserv->{'twofactor_test'};
$key =~ /^\S+$/ || return $text{'twofactor_eapikey'};
my $host = $test ? "sandbox-api.authy.com" : "api.authy.com";
my $port = $test ? 80 : 443;
my $page = "/protected/xml/app/details?api_key=".&urlize($key);
my $ssl = $test ? 0 : 1;
my ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl, undef, undef,
	       60, 0, 1);
if ($err =~ /401/) {
	return $text{'twofactor_eauthykey'};
	}
elsif ($err) {
	return &text('twofactor_eauthy', $err);
	}
$miniserv->{'twofactor_apikey'} = $key;
return undef;
}

# show_twofactor_form_authy(&webmin-user)
# Returns HTML for a form for enrolling for Authy two-factor
sub show_twofactor_form_authy
{
my ($user) = @_;
my $rv;
$rv .= &ui_table_row($text{'twofactor_email'},
	&ui_textbox("email", undef, 40));
$rv .= &ui_table_row($text{'twofactor_country'},
	&ui_textbox("country", undef, 3));
$rv .= &ui_table_row($text{'twofactor_phone'},
	&ui_textbox("phone", undef, 20));
return $rv;
}

# parse_twofactor_form_authy(&in, &user)
# Parses inputs from show_twofactor_form_authy, and returns a hash ref with
# enrollment details on success, or an error message on failure.
sub parse_twofactor_form_authy
{
my ($in, $user) = @_;
$in->{'email'} =~ /^\S+\@\S+$/ || return $text{'twofactor_eemail'};
$in->{'country'} =~ s/^\+//;
$in->{'country'} =~ /^\d{1,3}$/ || return $text{'twofactor_ecountry'};
$in->{'phone'} =~ /^[0-9\- ]+$/ || return $text{'twofactor_ephone'};
return { 'email' => $in->{'email'},
	 'country' => $in->{'country'},
	 'phone' => $in->{'phone'} };
}

# enroll_twofactor_authy(&details, &user)
# Attempts to enroll a user for Authy two-factor. Returns undef on success and
# sets twofactor_id in &user, or an error message on failure.
sub enroll_twofactor_authy
{
my ($details, $user) = @_;
my %miniserv;
&get_miniserv_config(\%miniserv);
my $host = $miniserv{'twofactor_test'} ? "sandbox-api.authy.com"
				       : "api.authy.com";
my $port = $miniserv{'twofactor_test'} ? 80 : 443;
my $page = "/protected/xml/users/new?api_key=".
	   &urlize($miniserv{'twofactor_apikey'});
my $ssl = $miniserv{'twofactor_test'} ? 0 : 1;
my $content = "user[email]=".&urlize($details->{'email'})."&".
	      "user[country_code]=".&urlize($details->{'country'})."&".
	      "user[cellphone]=".&urlize($details->{'phone'});
my ($out, $err);
&http_post($host, $port, $page, $content, \$out, \$err, undef, $ssl, undef,
	   undef, 60, 0, 1);
return $err if ($err);
if ($out =~ /<id[^>]*>([^<]+)<\/id>/i) {
	$user->{'twofactor_id'} = $1;
	$user->{'twofactor_apikey'} = $miniserv{'twofactor_apikey'};
	return undef;
	}
else {
	return &text('twofactor_eauthyenroll',
		     "<pre>".&html_escape($out)."</pre>");
	}
}

# validate_twofactor_authy(id, token, apikey)
# Checks the validity of some token for a user ID
sub validate_twofactor_authy
{
my ($id, $token, $apikey) = @_;
$id =~ /^\d+$/ || return $text{'twofactor_eauthyid'};
$token =~ /^\d+$/ || return $text{'twofactor_eauthytoken'};
my %miniserv;
&get_miniserv_config(\%miniserv);
my $host = $miniserv{'twofactor_test'} ? "sandbox-api.authy.com"
				       : "api.authy.com";
my $port = $miniserv{'twofactor_test'} ? 80 : 443;
my $page = "/protected/xml/verify/$token/$id?api_key=".&urlize($apikey).
	   "&force=true";
my $ssl = $miniserv{'twofactor_test'} ? 0 : 1;
my ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl, undef, undef,
	       60, 0, 1);
if ($err && $err =~ /401/) {
	# Token rejected
	return $text{'twofactor_eauthyotp'};
	}
elsif ($err) {
	# Some other error
	return $err;
	}
elsif ($out && $out =~ /<success[^>]*>([^<]+)<\/success>/i) {
	if (lc($1) eq "true") {
		# Worked!
		return undef;
		}
	elsif ($out =~ /<message[^>]*>([^<]+)<\/message>/i) {
		# Failed, but with a message
		return $1;
		}
	else {
		# Failed, not sure why
		return $out;
		}
	}
else {
	# Unknown output
	return $out;
	}
}

# validate_twofactor_apikey_totp()
# Checks that the needed Perl module for TOTP is installed.
sub validate_twofactor_apikey_totp
{
return undef;
}

# show_twofactor_form_totp(&user)
# Show form allowing the user to choose a twofactor secret
sub show_twofactor_form_totp
{
my ($user) = @_;
my $secret = $user->{'twofactor_id'};
$secret = undef if ($secret !~ /^[A-Z0-9=]+$/i ||
		    (length($secret) != 16 && length($secret) != 26 && length($secret) != 32));
my $rv;
$rv .= &ui_table_row($text{'twofactor_secret'},
	&ui_opt_textbox("totp_secret", $secret, 20, $text{'twofactor_secret1'},
			$text{'twofactor_secret0'}));
return $rv;
}

# parse_twofactor_form_totp(&in, &user)
# Generate or use a secret key for this user
sub parse_twofactor_form_totp
{
my ($in, $user) = @_;
if ($in->{'totp_secret_def'}) {
	$user->{'twofactor_id'} = &encode_base32(&generate_base32_secret());
	}
else {
	$in{'totp_secret'} =~ /^[A-Z0-9=]{16}$/i ||
		return $text{'twofactor_esecret'};
	$user->{'twofactor_id'} = $in{'totp_secret'};
	}
return { };
}

# generate_base32_secret([length])
# Returns a base-32 encoded secret of by default 10 bytes
sub generate_base32_secret
{
my ($length) = @_;
$length ||= 10;
&seed_random();
my $secret = "";
while(length($secret) < $length) {
	$secret .= chr(rand()*256);
	}
return $secret;
}

# enroll_twofactor_totp(&in, &user)
# Generate a secret for this user, based-32 encoded
sub enroll_twofactor_totp
{
my ($in, $user) = @_;
$user->{'twofactor_id'} ||= &encode_base32(&generate_base32_secret());
return undef;
}

# message_twofactor_totp(&user)
# Returns HTML to display after a user enrolls
sub message_twofactor_totp
{
my ($user) = @_;
my $name = &get_display_hostname()." (".$user->{'name'}.")";
my $str = "otpauth://totp/".$name."?secret=".$user->{'twofactor_id'};
my $url;
if (&can_generate_qr()) {
	if (&get_product_name() eq 'usermin') {
		$url = "qr.cgi?size=6&str=".&urlize($str);
		}
	else {
		$url = "$gconfig{'webprefix'}/webmin/qr.cgi?".
		       "size=6&str=".&urlize($str);
		}
	}
else {
	$url = "https://api.qrserver.com/v1/create-qr-code/?".
	       "size=200x200&data=".&urlize($str);
	}
my $rv;
$rv .= &text('twofactor_qrcode', "<tt>$user->{'twofactor_id'}</tt>")."<p>\n";
$rv .= "<img src='$url' border=0><p>\n";
return $rv;
}

# validate_twofactor_totp(id, token)
# Checks the validity of some token with TOPT
sub validate_twofactor_totp
{
my ($id, $token) = @_;
$id =~ /^[A-Z0-9=]+$/i || return $text{'twofactor_etotpid'};
$id = &decode_base32($id);
$token =~ /^\d+$/ || return $text{'twofactor_etotptoken'};
eval "use lib (\"$root_directory/vendor_perl\")";
eval "use Digest::HMAC_SHA1 qw/ hmac_sha1 /;";
my $now = time();
my $totp = sub {
	my ($secret, $time) = @_;
	
	# Compute HMAC-SHA1
	my $data = pack('H*', sprintf("%016x", int($time / 30)));
	my $packed_key = pack('H*', unpack("H*", $secret));
	my $hmac = hmac_sha1($data, $packed_key);

	# Convert HMAC to hexadecimal
	my $hmac_hex = unpack("H*", $hmac);

	# Generate the TOTP
	my $offset = hex(substr($hmac_hex, -1));
	my $part1 = hex(substr($hmac_hex, $offset * 2, 8));
	my $part2 = hex("7fffffff");
	return substr(($part1 & $part2), -6);
	};
foreach my $t ($now - 30, $now, $now + 30) {
	my $expected = $totp->($id, $t);
	return undef if ($expected eq $token);
	}
return $text{'twofactor_etotpmatch'};
}

# get_user_twofactor(username, &miniserv)
# Returns the twofactor provider, ID and API key for a user
sub get_user_twofactor
{
my ($user, $miniserv) = @_;
return () if (!$miniserv->{'twofactorfile'});
my $lref = &read_file_lines($miniserv->{'twofactorfile'}, 1);
foreach my $l (@$lref) {
	my @two = split(/:/, $l, -1);
	if ($two[0] eq $user) {
		return ($two[1], $two[2], $two[3]);
		}
	}
return ();
}

# save_user_twofactor(username, &miniserv, [provider, id, api-key])
# Updates or removes the twofactor provider for a user
sub save_user_twofactor
{
my ($user, $miniserv, $prov, $id, $key) = @_;
return 0 if (!$miniserv->{'twofactorfile'});
&lock_file($miniserv->{'twofactorfile'});
my $lref = &read_file_lines($miniserv->{'twofactorfile'});
my $found = 0;
my $i = 0;
foreach my $l (@$lref) {
	my @two = split(/:/, $l, -1);
	if ($two[0] eq $user) {
		# Found the line to update or remove
		if ($prov) {
			$lref->[$i] = join(":", $user, $prov, $id, $key);
			}
		else {
			splice(@$lref, $i, 1);
			}
		$found++;
		last;
		}
	$i++;
	}
if (!$found && $prov) {
	# Need to add the user
	push(@$lref, join(":", $user, $prov, $id, $key));
	}
&flush_file_lines($miniserv->{'twofactorfile'});
&unlock_file($miniserv->{'twofactorfile'});
}

# can_generate_qr()
# Returns 1 if QR codes can be generated on this system
sub can_generate_qr
{
if (&has_command("qrencode")) {
	return 1;
	}
eval "use Image::PNG::QRCode";
if (!$@) {
	return 1;
	}
return 0;
}

# generate_qr_code(string, [block-size])
# Turn a string into a QR code image, and returns the data and MIME type
sub generate_qr_code
{
my ($str, $size) = @_;
if (&has_command("qrencode")) {
	# Use the qrencode shell command
	my $cmd = "qrencode -o - -t PNG ".quotemeta($str);
	$cmd .= " -s ".quotemeta($size) if ($size);
	my ($out, $err);
	my $ex = &execute_command($cmd, undef, \$out, \$err);
	if ($ex) {
		return (undef, $err);
		}
	return ($out, "image/png");
	}
eval "use Image::PNG::QRCode";
if (!$@) {
	# Use a Perl module
	my $out;
	Image::PNG::QRCode::qrpng(
		text => $str,
		scale => $size || 6,
		out => \$out,
		);
	return ($out, "image/png");
	}
return (undef, "QR code generation requires either the qrencode command or ".
	       "Image::PNG::QRCode Perl module");
}

1;
