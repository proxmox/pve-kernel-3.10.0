#!/usr/bin/perl -w

use strict;
use File::Basename;
use File::Path;

my $fwsrc0 = "linux-2.6-2.6.32/firmware";
my $fwsrc1 = "linux-firmware.git";
my $fwsrc3 = "firmware-misc";

my $fwlist = shift;
die "no firmware list specified" if !$fwlist || ! -f $fwlist;

my $target = shift;
die "no target directory" if !$target || ! -d $target;

my $force_skip = {

    # not needed, the HBA has burned-in firmware
    'ql8100_fw.bin' => 1,
};

my $skip = {};
# debian squeeze also misses those files
foreach my $fw (qw(
libertas/gspi8385.bin libertas/gspi8385_hlp.bin
ctfw.bin ct2fw.bin ctfw-3.0.3.1.bin ct2fw-3.0.3.1.bin
cbfw.bin cbfw-3.0.3.1.bin 
tehuti/firmware.bin
cyzfirm.bin
isi4616.bin
isi4608.bin
isi616em.bin
isi608.bin
isi608em.bin
c320tunx.cod
cp204unx.cod
c218tunx.cod
isight.fw
BT3CPCC.bin
bfubase.frm
solos-db-FPGA.bin
solos-Firmware.bin
solos-FPGA.bin
pca200e_ecd.bin2
prism2_ru.fw
tms380tr.bin
FW10 
FW13
comedi/jr3pci.idm

sd8686.bin
sd8686_helper.bin 
usb8388.bin
libertas_cs_helper.fw
lbtf_usb.bin

wl1271-fw.bin
wl1251-fw.bin
symbol_sp24t_sec_fw
symbol_sp24t_prim_fw
prism_ap_fw.bin
prism_sta_fw.bin
ar9170.fw
iwmc3200wifi-lmac-sdio.bin
iwmc3200wifi-calib-sdio.bin
iwmc3200wifi-umac-sdio.bin
iwmc3200top.1.fw
zd1201.fw
zd1201-ap.fw
isl3887usb
isl3886usb
isl3886pci
3826.arm

i2400m-fw-sdio-1.3.sbcf

nx3fwmn.bin
nx3fwct.bin
nxromimg.bin

myri10ge_rss_eth_z8e.dat
myri10ge_rss_ethp_z8e.dat
myri10ge_eth_z8e.dat
myri10ge_ethp_z8e.dat

i1480-phy-0.0.bin
i1480-usb-0.0.bin
i1480-pre-phy-0.0.bin

go7007fw.bin
go7007tv.bin

sep/resident.image.bin
sep/cache.image.bin
b43legacy/ucode4.fw
b43legacy/ucode2.fw 
b43/ucode9.fw
b43/ucode5.fw
b43/ucode15.fw
b43/ucode14.fw
b43/ucode13.fw
b43/ucode11.fw
b43/ucode16_mimo.fw
orinoco_ezusb_fw
isl3890
isl3886
isl3877
mwl8k/fmimage_8366.fw
mwl8k/helper_8366.fw
mwl8k/fmimage_8363.fw
mwl8k/helper_8363.fw
iwlwifi-6000g2a-4.ucode
iwlwifi-6000g2a-6.ucode
iwlwifi-130-5.ucode
iwlwifi-100-6.ucode
iwlwifi-1000-6.ucode
cxgb4/t4fw.bin
cxgb4/t4fw-1.3.10.0.bin

)) {
    $skip->{$fw} = 1;
}

sub copy_fw {
    my ($src, $dstfw) = @_;

    my $dest = "$target/$dstfw";

    return if -f $dest;

    mkpath dirname($dest);
    system ("cp '$src' '$dest'") == 0 || die "copy $src to $dest failed";
}

my $fwdone = {};

open(TMP, $fwlist);
while(defined(my $line = <TMP>)) {
    chomp $line;
    my ($fw, $mod) = split(/\s+/, $line, 2);

    next if $mod =~ m|^kernel/sound|;
    next if $mod =~ m|^kernel/drivers/isdn|;

    # skip ZyDas usb wireless, use package zd1211-firmware instead
    next if $fw =~ m|^zd1211/|; 

    # skip atmel at76c50x wireless networking chips.
    # use package atmel-firmware instead
    next if $fw =~ m|^atmel_at76c50|;

    # skip Bluetooth dongles based on the Broadcom BCM203x 
    # use package bluez-firmware instead
    next if $fw =~ m|^BCM2033|;

    next if $force_skip->{$fw};

    next if $fwdone->{$fw};
    $fwdone->{$fw} = 1;

    my $fwdest = $fw;
    if ($fw eq 'libertas/gspi8686.bin') {
	$fw = 'libertas/gspi8686_v9.bin';
    }
    if ($fw eq 'libertas/gspi8686_hlp.bin') {
	$fw = 'libertas/gspi8686_v9_helper.bin';
    }

    if ($fw eq 'PE520.cis') {
	$fw = 'cis/PE520.cis';
    }
 
    # the rtl_nic/rtl8168d-1.fw file is buggy in current kernel tree
    if (-f "$fwsrc0/$fw" && 
	($fw ne 'rtl_nic/rtl8168d-1.fw')) { 
	copy_fw("$fwsrc0/$fw", $fwdest);
	next;
    }
    if (-f "$fwsrc1/$fw") {
	copy_fw("$fwsrc1/$fw", $fwdest);
	next;
    }
    if (-f "$fwsrc3/$fw") {
	copy_fw("$fwsrc3/$fw", $fwdest);
	next;
    }

    if ($fw =~ m|/|) {
	next if $skip->{$fw};
	die "unable to find firmware: $fw $mod\n";
    }

    my $name = basename($fw);

    my $sr = `find '$fwsrc1' -type f -name '$name'`;
    chomp $sr;
    if ($sr) {
	#print "found $fw in $sr\n";
	copy_fw($sr, $fwdest);
	next;
    }
    $sr = `find '$fwsrc3' -type f -name '$name'`;
    chomp $sr;
    if ($sr) {
	#print "found $fw in $sr\n";
	copy_fw($sr, $fwdest);
	next;
    }

    next if $skip->{$fw};

    die "unable to find firmware: $fw $mod\n";
}
close(TMP);

exit(0);
