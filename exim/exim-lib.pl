# exim-lib.pl
# Common functions for parsing exim config files

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
use Tie::File;

$exim_virt_dir = "$config{'exim_virt_dir'}";

$config{'exim_aliasfileextre'} = "$config{'exim_aliasfileext'}";
$config{'exim_aliasfileextre'} =~ s/\./\\./g;

# user_mail_file(&user)
# get mbox/maildir name
sub user_mail_file
{
	my ($user) = @_;
	if( !$user->{'home'} )
	{ return 0; }

	return "$user->{'home'}/$config{'exim_mail_file'}";
}

# remove_domain(&domain)
# Remove exim data regarding the domain
sub remove_domain($)
{
	my ($domain) = @_;

	# remove alias file
	my $file = &alias_path($domain);
	`rm $file`;

	if( $config{'exim_dbmfile'} )
	{
		# remove local_domains entry
		&process_file(op=>'delete',
			file=>$config{'exim_dbmfile'},
			pat=>"^\\*\\.$domain:",
			onlyFirst=>1);

		# remove dbm file
		my $file = &alias_path($domain,1);
		if( -e $file )
		{ `rm $file`; }
	}
}

# add_local_domain(&domain)
# Add a local domain
sub add_local_domain($)
{
	my ($domain) = @_;

	if( $config{'exim_dbmfile'} )
	{
		open( LD, ">>$config{'exim_dbmfile'}" );
		print LD "*.$domain:\t".&alias_path($domain,1)."\n";
		close( LD );
	}
}

# alias_path(&domain,[dbm])
# Return path to an alias file
sub alias_path($)
{
	my ($domain,$dbm) = @_;
	if( $dbm )
	{ return "$exim_virt_dir/$domain$config{'exim_dbmext'}"; }
	else
	{ return "$exim_virt_dir/$domain$config{'exim_aliasfileext'}"; }
}

# create_aliases_file(&domain)
# Creates an exim alias file
sub create_aliases_file($)
{
	my($domain) = shift(@_);

	$file = &alias_path($domain);

	if ( ! -e $file )
    {
        open(CONF,"> $file");
        print CONF <<EOF;

*: :fail: That user does not exist.
EOF
		close(CONF);
	}
}

# create_alias(&alias)
# Creates a new exim alias
sub create_alias
{
	local $alias = $_[0]->{'name'};
	local $domain = $_[0]->{'dom'};
	local $to = $_[0]->{'values'};


    local $tos;
	for (@$to)
	{ s/^\\+//; }			    
	$tos = join(',',@$to);

	&create_aliases_file($domain);
    
	&process_file(op=>"insertBefore",
		file=>&alias_path($domain),
		pat=>"^\\*:",
		text=>"$alias:\t$tos",
		onlyFirst=>1);

	# update email-addresses
	if( $alias =~ /\@/ )
	{ return; }

	if( $config{'exim_addrfile'} )
	{
		local $em = `cat $config{'exim_addrfile'}`;

		if( !($em =~ /@$to[0]\t/) )
		{
			&process_file(op=>"insertBefore",
	            file=>$config{'exim_addrfile'},
	            text=>"@$to[0]\t$alias\@$domain" );
		}
	}
}

# modify_alias(&old, &alias)
# Modifies an existing exim alias
sub modify_alias(&old, &alias)
{
	&delete_alias($_[0]);
	&create_alias($_[1]);
}

# delete_alias(&alias)
# Deletes an existing exim alias file
sub delete_alias
{
	local $alias = $_[0]->{'name'};
	local $domain = $_[0]->{'dom'};

	&process_file(op=>"delete",
		file=>&alias_path($domain),
		pat=>"^$alias\[:\\s\]",
		onlyFirst=>1);

	if( $config{'exim_addrfile'} )
	{
		&process_file(op=>"delete",
	    	file=>$config{'exim_addrfile'},
	    	pat=>"\\t\\S*\@$domain\$" );
	}
}

# list_domains
# List all domains from the exim alias file dir
sub list_domains
{
	opendir(DIR, $exim_virt_dir);
	@files = readdir(DIR);
	closedir(DIR);

	for my $file (@files)
	{ $file =~ s/$config{'exim_aliasfileextre'}$//g; }

	return @files;
}

# list_virtusers
# Go through exim alias files and build list of users.
sub list_virtusers
{
	opendir(DIR,$exim_virt_dir);
	@files = sort(grep(/$config{'exim_aliasfileextre'}$/,readdir(DIR)));
	closedir(DIR);

	local $num = 1;

	local (@virts);

	$all_data = "";
	foreach $file (@files) {
		$file =~ /^(.*)$config{'exim_aliasfileextre'}/;
		$domain = $1;
		$file_line = 1;
		open(FILE,"$exim_virt_dir/$file") || die("Could not find $file. $!");
		while ( <FILE> )
		{
			if ( /^([^\*\#\s:]+):?\s+(.*)$/ )
			{
				$lhs = $1;
				$rhs = $2;
				if ( $rhs =~ /mailman/ )
				{
					#print $line;
				}
				else
				{
					if ( $rhs ne "dummyspamaccount" )
					{
						my $from = "$lhs\@$domain";
						local @tos = split(/,/,$rhs);
						local %rv = ( 'from' => $from,
										'cmt' => undef);

						local %virt = ( 'number' => $num++,
										'value' => @tos,
										'file' => "$dir/$file",
										'name' => $from,
										'cmt' => undef,
										'eline' => $file_line,
										'map_file' => "$dir/$file",
										'line' => $file_line);

						$rv{'virt'} = \%virt;
						$rv{'to'} = \@tos;
						push(@virts, \%rv);
					}
				}
			}
			$file_line++;
		}
		close(FILE);
	}
	return @virts;
}

# process_file(...)
# Go through lines of a file and do various operations based on regexp
# matching.
sub process_file
{
	my(%args) = @_;
	
	my $hitunless = 0;
	my $inrange = 0;
	my $endfound = 0;
	my $operation = $args{'op'};
	my $file = $args{'file'};
	my $pattern = $args{'pat'};
	my $cc = defined $args{'cc'} ? $args{'cc'} : "#"; 

	my $opCount = 0;
	if ( $operation eq "uncomment" )
	{
		$pattern = "^$cc.*" . $pattern;
	}
	
	my $tie_obj =
	tie my @contents, 'Tie::File', $file || die "Couldn't open $file: $!.  Exiting...\n";
	$tie_obj->flock;

	my $i=0;
	my $skip = 0;
	for ( @contents )
	{
		if ( $skip == 1 )
		{
			$skip = 0;
			next;
		}
		if ( defined($args{'startrange'}) && defined($args{'endrange'}) && $_ =~ /$args{'startrange'}/ )
		{
			$inrange = 1;
		}
		if ( defined($args{'endrange'}) && $_ =~ /$args{'endrange'}/ )
		{
			$endfound = 1;
		}
		if ( defined($args{'unless'}) && $_ =~ /$args{'unless'}/ )
		{
			$hitunless = 1;
			last;
		}

		if ( ( defined($pattern) && $_ =~ /$pattern/ ) || $inrange == 1 )
		{
			if ( $operation eq "comment" )
			{
				s/$_/$cc $&/;
				$opCount++;
			}
			elsif ( $operation eq "uncomment" )
			{
            	s/$cc\s?//;
				$opCount++;
			}
			elsif ( $operation eq "delete" )
			{
				splice(@contents,$i,1);
				$opCount++;
				if ( $endfound == 1 )
				{
					$inrange = 0;
					$endfound = 0;
				}
				redo if ( ( !defined($args{'onlyFirst'}) || $inrange == 1 ) && $#contents != -1 );
			}
			elsif ( $operation eq "insertBefore" )
			{
				splice(@contents,$i,0,$args{'text'});
				$opCount++;
				$skip++;
			}
			elsif ( $operation eq "replace" )
			{
				$_ = $args{'text'};
				$opCount++;
			}
			if ( defined $args{'onlyFirst'} )
			{
				last;
			}
		}
		if ( $endfound == 1 )
		{
			$inrange = 0;
			$endfound = 0;
		}
		$i++;
	}

	if ( $operation eq "insertBefore" && $opCount == 0 && $hitunless == 0 )
	{
		push(@contents, $args{'text'}); 
	}
	
	untie @contents;
}



1;

