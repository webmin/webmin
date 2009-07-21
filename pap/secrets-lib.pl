# secrets-lib.pl
# Common functions for editing a PPP users file

# list_secrets()
sub list_secrets
{
local(@rv, $line, $_);
open(SEC, $config{'pap_file'});
$line = 0;
while(<SEC>) {
	chop;
	s/^#.*$//g;
	@w = &split_words($_);
	if (@w >= 3) {
		local(%sec, @ips);
		$sec{'client'} = $w[0];
		$sec{'server'} = $w[1];
		$sec{'secret'} = $w[2];
		@ips = @w[3..$#w];
		$sec{'ips'} = \@ips;
		$sec{'line'} = $line;
		$sec{'index'} = scalar(@rv);
		push(@rv, \%sec);
		}
	$line++;
	}
close(SEC);
return @rv;
}

# create_secret(&secret)
sub create_secret
{
&open_tempfile(SEC, ">>$config{'pap_file'}");
&print_tempfile(SEC, &join_words($_[0]->{'client'}, $_[0]->{'server'},
		      $_[0]->{'secret'}, @{$_[0]->{'ips'}}),"\n");
&close_tempfile(SEC);
}

# change_secret(&secret)
sub change_secret
{
&replace_file_line($config{'pap_file'}, $_[0]->{'line'},
		   &join_words($_[0]->{'client'}, $_[0]->{'server'},
			       $_[0]->{'secret'}, @{$_[0]->{'ips'}})."\n");
}

# delete_secret(&secret)
sub delete_secret
{
&replace_file_line($config{'pap_file'}, $_[0]->{'line'});
}

# split_words(string)
sub split_words
{
local($s, @w);
$s = $_[0];
while($s =~ /^\s*([^"\s]+|"([^"]*)")(.*)$/) {
	push(@w, defined($2) ? $2 : $1);
	$s = $3;
	}
return @w;
}

sub join_words
{
local(@w, $w);
foreach $w (@_) {
	if ($w =~ /^[a-zA-Z0-9\.\-]+$/) { push(@w, $w); }
	else { push(@w, "\"$w\""); }
	}
return join("  ", @w);
}

# opt_crypt(password)
# Returns the given password, crypted if the user has configured it
sub opt_crypt
{
if ($config{'encrypt_pass'}) {
	local($salt);
	srand(time());
	$salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
	return &unix_crypt($_[0], $salt);
	}
return $_[0];
}


