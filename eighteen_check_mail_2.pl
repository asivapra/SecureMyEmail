#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_check_deliver_hold.pl
# Created on 16 June, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

#Purpose: Analyse the mails in $qmailDir/.../tmp
#This runs as a daemon with 1sec sleep.
#Deliver if mail is from known sender and known IP
#Deliver if known sender with no IP recorded. Add the IP
#Drop if unknown sender and invalid HELO, etc.
#Pass to 'quarantine.pl' if unknown sender or known sender with no IP match
#--------------------------------------

require "./eighteen_common.pl";
require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";
use DBI;

sub BlockedWarning
{
	&RecordLogs("BlockedWarning = $senderEmail to $recipientEmail\n");
	$textmailbody = "<pre>
Your email sent to $recipientEmail has been blocked due to excessive spam characteristics.
	
Subject: $subject
From: $senderEmail
To: $recipientEmail

Please DO NOT reply to this automatic email. If you believe that the blockage is in error, please try to
contact the recipient by other means such as phone or Skype.

--
Postmaster.
</pre>
";
	open (INP, "<$challenge_template");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	$mailbody = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$mailbody .= &WSCPReplaceTags($filecontent[$j]);
	}
	$Form_subject_user = "Re: $subject";
	&PutHeadersInAckMailFile ($Owner_name, $noreplyEmail, $noreplyEmail, $noreplyEmail, $senderEmail, $Form_subject_user);
    $tfilecontent .= "\n--------------The Following is in HTML Format\n";
    $tfilecontent .= "Content-Type: text/html; charset=us-ascii\n";
    $tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
    $tfilecontent .= "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
	$tfilecontent .= $textmailbody;
    $tfilecontent .= "\n--------------The Following is in HTML Format--\n";
	my $filename = "$tmpDir/sme_$$.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	`$mailprogram -f $noreplyEmail $senderEmail < $filename`;
	$mailerror = $?;
print("SendBlockedWarning: mailerror = $mailerror;	`$mailprogram -f $noreplyEmail $senderEmail < $filename`;\n");
   	unlink ($filename);
}

sub CheckSenderEmailInBlackList
{
	@senderEmail = split (/\@/, $senderEmail);
	$senderDomain = $senderEmail[1];
	$senderDomain = "\*\@$senderDomain";
	@recipientEmail = split (/\@/, $recipientEmail);
	$recipientDomain = $recipientEmail[1];
	$recipientDomain = "\*\@$recipientDomain";
	$query = "select count(*) from `blacklist` where ((senderEmail='$senderEmail' or senderEmail = '$senderDomain') and (userUrk=$userUrk or userUrk = $sharedUrk))";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	return $results[0];  # Check the DB before returning
}
sub QuarantineTheMail
{
	&GetThreeLines;
	$quarantinedMail = "$quarantinemailDir/$urk";
	&RecordLogs("Quarantine = $quarantinedMail\n");
	`chmod 644 $mailfile`; # Set the prot to 644 so that the admin can view the message content via HT
	`mv '$mailfile' $quarantinedMail`;  # Move it from /var/qmail/mailnames/quarantine/tmp to /var/qmail/mailnames/quarantine
	$qerr = $?;
	$subject =~ s/\'//gi;

	$query = "select DATE_ADD(concat(date_format(now(),'%Y-%m-%d'),' 23:59:59'), INTERVAL $mailpurge DAY)";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$expiry_date = $results[0];
	my $Clean_email = $userOut;
	if (!$Clean_email) { $Clean_email = $Raw_email; }

	$safeSubject = &SafeSubject($subject);
	my $notified = 0;
	if ($blocked) { $notified = -2; }
	$query = "insert into `quarantine` (urk,Message_ID,senderEmail,recipientEmail,subject,quarantinedMail,Clean_email,Alt_Clean_email,sascore,ip,expiry_date,challenge,alert,userUrk,hashcode,threelines,lmode,notified) 
	values ($urk,'$Message_ID','$senderEmail','$recipientEmail','$safeSubject','$quarantinedMail','$Clean_email','$Alt_Clean_email','$sascore','$ip','$expiry_date',$challenge,$alert,$userUrk,'$hashcode','$ThreeLinesContent','$lmode','$notified')";
	&execute_query($query);
}

sub DeliverCleanMails
{
	if ($senderEmail =~ /MAILER-DAEMON\@zulu282.startdedicated.com/)
	{
		my $mailer_deamon = 'mailer-daemon@webgenie.com';
		`$mailprogram -f $senderEmail $mailer_deamon < $mailfile`;
		$mailerror = $?;
		if (!$mailerror)
		{
			&RecordLogs("RM8: Delivery Failure: Sent from $senderEmail to $mailer_deamon - $subject\n");	
		}
		else
		{
			&RecordLogs("RM9: Delivery Failure: Could not send from $senderEmail - $subject\n");	
		}
		&QuarantineTheMail; # Place the mail in holding tray. A separate program will process them for alerts
		$deliveredAsClean = 1; # This mail has been sent to mailer-daemon@webgenie.com
		return;
	}
	$mailDeleted = 0;
	$blocked = &CheckSenderEmailInBlackList;
	if ($blocked) 
	{ 
		&RecordLogs("RM4: Blocked address:$senderEmail - NOT Deleted\n");	
		&BlockedWarning;		
		$query = "update `statistics` set blk=blk+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
		$mailDeleted = 1;
		&QuarantineTheMail; # Place the mail in holding tray. A separate program will process them for alerts
		return 1; 
	}
	else
	{
		$knownuser = &ChecksenderEmailAndIPinWhiteList;
		&RecordLogs("Known Sender = $knownuser; ");				
		if ($knownuser > 0)
		{
			&DeliverToCleanMailbox;
			&UpdateHistoryTable($cleanmailcode);
			$query = "update `statistics` set clean=clean+1 where userUrk=$userUrk and day=0";
			&execute_query($query);
			$safeSubject = &SafeSubject($subject);
			$query = "insert into `quarantine` (urk,Message_ID,senderEmail,recipientEmail,subject,Clean_email,Alt_Clean_email,sascore,ip,challenge,alert,userUrk,hashcode,accept_method,delivered,lmode) values 
			($urk,'$Message_ID','$senderEmail','$recipientEmail','$safeSubject','$Clean_email','$Alt_Clean_email','$sascore','$ip',$challenge,$alert,$userUrk,'$hashcode','C',2,'$lmode')";
			&execute_query($query);
			$deliveredAsClean = 1;
		}
	}
}

sub WeedOut
{
	if ($senderEmail !~ /\@/) 
	{
&RecordLogs("RM1: Invalid senderEmail: $senderEmail;\n");				
	   &QuarantineTheMail; # Place the mail in holding tray. A separate program will process them for alerts
		&UpdateHistoryTable($invalidSenderEmailcode);
		$spam++;
		return 1; 
	}
	if ($invalidHelo) 
	{ 
&RecordLogs("RM2: HELO is Invalid: $heloField\n");				
		&UpdateHistoryTable($invalidHelocode);
		$spam++;
		return 0; 
	}
	$foreignSubj = &CheckIfForeignLanguage;  # Drop if subject is Foreign language
	if ($foreignSubj && !$keepForeignSubject) # keepForeignSubject will become a user option
	{ 
&RecordLogs("RM3: Foreign Subject.\n");				
		&UpdateHistoryTable($foreignSubjectcode);
		`rm $mailfile`;
		$spam++;
		return 1; 
	}
	if($subject) { $blockedSubj = &CheckIfBlockedSubject; }  
	if ($blockedSubj) 
	{ 
&RecordLogs("RM5: Blocked Subject.\n");				
		&UpdateHistoryTable($blockedSubjectcode);
		`rm $mailfile`;
		$spam++;
		return 1; 
	}
	if(&CheckIfBannedCountry) 
	{ 
&RecordLogs("RM6: Blocked TLD.\n");				
#		`rm $mailfile`;
		$spam++;
		return 1; 
	}
	if(&CountryCheck) 
	{ 
&RecordLogs("RM7: Blocked Country.\n");				
#		`rm $mailfile`;
		$spam++;
		return 1; 
	}
	return 0;
}
sub GetRandomURK
{
	$n = 10;
	$numeric = '1234567890';
	@numeric = split (//, $numeric);
	$randomString = "";
	for (my $j=0; $j <= $n; $j++)
	{
		srand;  # Seed the random number
		$i = int (rand (10));  # Get a random start position
		$randomString .= $numeric[$i];
	}
	return $randomString;
}
sub CheckMails
{
	$tmpmailDir   = "$qmailDir/$domain/$userIn/Maildir/tmp";
	opendir (DIR, "$tmpmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $tmpmailDir/* $quarantinemailDirTmp`;  # Move from 'tmp' to 'quarantinemailDir'
	}
	for ($j=0; $j <= $len; $j++) # 0 and 1 are . and ..
	{
		$mailfile = "$quarantinemailDirTmp/$inputRecords[$j]";
		if (-f $mailfile)
		{
			$incoming++;
			$urk = &GetRandomURK; # Get an 11-digit random number
			$msgID = $urk;
			$query = "update `statistics` set inc=inc+1 where userUrk=$userUrk and day=0";
			&execute_query($query);
			&GetsenderEmailAndIP('check_mail_2:CheckMails'); # Gets SendEmail, RecipEmail, IP, Subject; Records subject in `subjects`

# If blank it is sending spam that falls below sascore
			if (!$ip) { $ip = '0.0.0.0'; }
			
			$query = "insert into `history` (msgID,userUrk,senderEmail,recipientEmail,subject,action) values($msgID,$userUrk,'$senderEmail','$recipientEmail','$safeSubject',$incomingcode)";
			&execute_query($query);

#			$skip = &WeedOut;  # Drop if mail is obvious spam or blocked ones
#
#			if ($skip) 
#			{ 
#				$query = "update `statistics` set spam=spam+1 where userUrk=$userUrk and day=0";
#				&execute_query($query);
#				next; 
#			}
#			$virus = &AntiVirusCheck; # Put through CLAMAV. This comes again before clean mail delivery
			if (!$virus)
			{
				$hashcode = &GetRandomChars(39);
				&DeliverCleanMails; # Deliver only if knownuser 
				if($deliveredAsClean) { next; }
$skip = &WeedOut;  # Drop if mail is obvious spam or blocked ones
if ($skip) 
{ 
	$query = "update `statistics` set spam=spam+1 where userUrk=$userUrk and day=0";
	&execute_query($query);
	next; 
}
				if ($virus) 
				{ 
					next; 
				}
				if ($knownuser <= 0 && !$mailDeleted)
				{
					if (!$skip)
					{
					   &QuarantineTheMail; # Place the mail in holding tray. A separate program will process them for alerts
					   eval
					   {
						 local $SIG{ALRM} = sub {die "query timeout\n"};
						 alarm 60;
						 system ("$quarantine_pl $urk $knownuser $lmode&"); # This is spawned separately, as spamc takes several seconds
						 alarm 0;
					   };
					
					   if ($@ =~ "query timeout\n")
					   {
&RecordLogs("Timeout: eighteen_quarantine.pl - $urk\n");				
						  exit;
					   }
					}
				}
			}
			else
			{
				&UpdateHistoryTable($viruscode);
				$query = "update `statistics` set vir=vir+1 where userUrk=$userUrk and day=0";
				&execute_query($query);
				# Discard the mail
				`rm $mailfile`; # Delete this for security reasons
&RecordLogs("File contains a Virus. Deleted: $virus\n");				
#print "File contains a Virus. Deleted: $virus\n";				
			}
		}
	}
}
sub GetmsgIDprefix
{
	# This function is not used now, but may be required later if spammers find out that adding '209.239.112.136' to Message-Id will pass the mails for gmail users. Until then, let us use the IP address which is cleaner to remember. 
	$query = "select hashcode from `admin_users` where User_email='$Admin_email'";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	if ($results[0])
	{
		$msgIDprefix = $results[0]; # The default $msgIDprefix is defined in diffs_dir.pl
	}
}
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
#&debugEnv;
	my $user = $ARGV[0];
	$cycle = 0;  # Check how many cycles covered
	&ConnectToDBase;
	my @fields = split (/\,/, $user);
	$Admin_email = $fields[0];
	$userIn = $fields[1];
		$Raw_email = $userIn;
	$userOut = $fields[2];
		$Clean_email = $userOut;
	$Alt_Clean_email = $fields[3];
	$challenge = $fields[4];
	$alert = $fields[5];
	$userUrk = $fields[6];
	$sharedUrk = $fields[7];
	$lmode = $fields[8];
	my @fields = split (/\@/, $userIn);
	$userIn = $fields[0];
	$domain = $fields[1];

	# Make a list of local domains so that it can checked whether the mail belongs to someone local or forwarded
	open (INP, "<$varqmail/control/rcpthosts");
	@localdomains = <INP>;
	close (INP);
	$localdomains = join ("|", @localdomains);
	$localdomains =~ s/\n//gi;
	$localdomains = "|$localdomains|";

	# This function is not used now, but may be required later if spammers find out that adding '209.239.112.136' to Message-Id will pass the mails for gmail users. Until then, let us use the IP address which is cleaner to remember. 
#	&GetmsgIDprefix; # This is the admin_users|hashcode value belonging to the owner of this a/c. It will be added to the 'Message-Id' before clean mails are forwarded

	&CheckMails;   # See if any new mail for the user and, if so, move to a temp dir
		
	$dbh->disconnect;
}
$|=1;
&do_main;

