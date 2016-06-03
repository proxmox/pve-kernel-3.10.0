RELEASE=3.4

KERNEL_VER=3.10.0
PKGREL=47
# also include firmware of previous versrion into 
# the fw package:  fwlist-2.6.32-PREV-pve
KREL=19

RHKVER=327.18.2.el7

KERNELSRCRPM=kernel-${KERNEL_VER}-${RHKVER}.src.rpm

EXTRAVERSION=-${KREL}-pve
KVNAME=${KERNEL_VER}${EXTRAVERSION}
PACKAGE=pve-kernel-${KVNAME}
HDRPACKAGE=pve-headers-${KVNAME}

ARCH=amd64
GITVERSION:=$(shell cat .git/refs/heads/master)

TOP=$(shell pwd)

KERNEL_SRC=linux-2.6-${KERNEL_VER}
RHKERSRCDIR=rh-kernel-src
KERNEL_CFG=config-${KERNEL_VER}

KERNEL_CFG_ORG=${RHKERSRCDIR}/kernel-${KERNEL_VER}-x86_64.config

FW_VER=1.1
FW_REL=5
FW_DEB=pve-firmware_${FW_VER}-${FW_REL}_all.deb

E1000EDIR=e1000e-3.3.3
E1000ESRC=${E1000EDIR}.tar.gz

IGBDIR=igb-5.3.4.4
IGBSRC=${IGBDIR}.tar.gz

IXGBEDIR=ixgbe-4.3.15
IXGBESRC=${IXGBEDIR}.tar.gz

I40EDIR=i40e-1.5.16
I40ESRC=${I40EDIR}.tar.gz

# does not compile with RHEL 7.2 (=327.3.1.el7)
BNX2DIR=netxtreme2-7.11.05
BNX2SRC=${BNX2DIR}.tar.gz

# does not compile with RHEL 7.2 (=327.3.1.el7)
AACRAIDVER=1.2.1-40700
AACRAIDDIR=aacraid-${AACRAIDVER}.src
AACRAIDSRC=aacraid-linux-src-${AACRAIDVER}.tgz

HPSAVER=3.4.6
HPSADIR=hpsa-${HPSAVER}
HPSASRC=${HPSADIR}-170.tar.bz2

# driver does not compile
#MEGARAID_DIR=megaraid_sas-06.703.11.00
#MEGARAID_SRC=${MEGARAID_DIR}-src.tar.gz

ARECADIR=arcmsr-1.30.0X.19-140509
ARECASRC=${ARECADIR}.zip

# this one does not compile with newer 3.10 kernels!
#RR272XSRC=RR272x_1x-Linux-Src-v1.5-130325-0732.tar.gz
#RR272XDIR=rr272x_1x-linux-src-v1.5

# this project look dead - no updates since 3 years
#ISCSITARGETDIR=iscsitarget-1.4.20.2
#ISCSITARGETSRC=${ISCSITARGETDIR}.tar.gz

SPLDIR=pkg-spl
SPLSRC=pkg-spl.tar.gz
ZFSDIR=pkg-zfs
ZFSSRC=pkg-zfs.tar.gz
ZFS_MODULES=zfs.ko zavl.ko znvpair.ko zunicode.ko zcommon.ko zpios.ko
SPL_MODULES=spl.ko splat.ko

DST_DEB=${PACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb
HDR_DEB=${HDRPACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb

all: check_gcc ${DST_DEB} ${FW_DEB} ${HDR_DEB}

.PHONY: download
download:
	rm -f ${KERNELSRCRPM}
	#wget http://vault.centos.org/7.0.1406/os/Source/SPackages/${KERNELSRCRPM}
	#wget http://vault.centos.org/7.0.1406/updates/Source/SPackages/${KERNELSRCRPM}
	wget http://vault.centos.org/7.2.1511/updates/Source/SPackages/${KERNELSRCRPM}

check_gcc: 
ifeq    ($(CC), cc)
	gcc --version|grep "4\.7\.2" || false
else
	$(CC) --version|grep "4\.7" || false
endif

${DST_DEB}: data control.in prerm.in postinst.in postrm.in copyright changelog.Debian
	mkdir -p data/DEBIAN
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <control.in >data/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <prerm.in >data/DEBIAN/prerm
	chmod 0755 data/DEBIAN/prerm
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <postinst.in >data/DEBIAN/postinst
	chmod 0755 data/DEBIAN/postinst
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <postrm.in >data/DEBIAN/postrm
	chmod 0755 data/DEBIAN/postrm
	install -D -m 644 copyright data/usr/share/doc/${PACKAGE}/copyright
	install -D -m 644 changelog.Debian data/usr/share/doc/${PACKAGE}/changelog.Debian
	echo "git clone git://git.proxmox.com/git/pve-kernel-3.2.0.git\\ngit checkout ${GITVERSION}" > data/usr/share/doc/${PACKAGE}/SOURCE
	gzip -f --best data/usr/share/doc/${PACKAGE}/changelog.Debian
	rm -f data/lib/modules/${KVNAME}/source
	rm -f data/lib/modules/${KVNAME}/build
	dpkg-deb --build data ${DST_DEB}
	lintian ${DST_DEB}


fwlist-${KVNAME}: data
	./find-firmware.pl data/lib/modules/${KVNAME} >fwlist.tmp
	mv fwlist.tmp $@

# fixme: bnx2.ko cnic.ko bnx2x.ko
# todo: aacraid.ko ?
data: .compile_mark ${KERNEL_CFG} e1000e.ko igb.ko i40e.ko ixgbe.ko arcmsr.ko hpsa.ko ${SPL_MODULES} ${ZFS_MODULES}
	rm -rf data tmp; mkdir -p tmp/lib/modules/${KVNAME}
	mkdir tmp/boot
	install -m 644 ${KERNEL_CFG} tmp/boot/config-${KVNAME}
	install -m 644 ${KERNEL_SRC}/System.map tmp/boot/System.map-${KVNAME}
	install -m 644 ${KERNEL_SRC}/arch/x86_64/boot/bzImage tmp/boot/vmlinuz-${KVNAME}
	cd ${KERNEL_SRC}; make INSTALL_MOD_PATH=../tmp/ modules_install
	# install latest i40e driver
	install -m 644 i40e.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/i40e/
	# install latest ixgbe driver
	install -m 644 ixgbe.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/ixgbe/
	# install latest e1000e driver
	install -m 644 e1000e.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/e1000e/
	# install latest ibg driver
	install -m 644 igb.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/igb/
	## install bnx2 drivers
	#install -m 644 bnx2.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/
	#install -m 644 cnic.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/
	#install -m 644 bnx2x.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/bnx2x/
	# install aacraid drivers
	#install -m 644 aacraid.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/aacraid/
	# install hpsa driver
	install -m 644 hpsa.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/
	# install megaraid_sas driver
	# install -m 644 megaraid_sas.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/megaraid/
	## install Highpoint 2710 RAID driver
	#install -m 644 rr272x_1x.ko -D tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/rr272x_1x/rr272x_1x.ko
	# install areca driver
	install -m 644 arcmsr.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/arcmsr/
	# install zfs drivers
	install -d -m 0755 tmp/lib/modules/${KVNAME}/zfs
	install -m 644 ${SPL_MODULES} ${ZFS_MODULES} tmp/lib/modules/${KVNAME}/zfs
	# remove firmware
	rm -rf tmp/lib/firmware
	# strip debug info
	find tmp/lib/modules -name \*.ko -print | while read f ; do strip --strip-debug "$$f"; done
	# finalize
	depmod -b tmp/ ${KVNAME}
	mv tmp data

.compile_mark: ${KERNEL_SRC}/README ${KERNEL_CFG}
	cp ${KERNEL_CFG} ${KERNEL_SRC}/.config
	cd ${KERNEL_SRC}; make oldconfig
	cd ${KERNEL_SRC}; make -j 8
	touch $@

${KERNEL_CFG}: ${KERNEL_CFG_ORG} config-${KERNEL_VER}.diff
	cp ${KERNEL_CFG_ORG} ${KERNEL_CFG}.new
	patch --no-backup ${KERNEL_CFG}.new config-${KERNEL_VER}.diff
	mv ${KERNEL_CFG}.new ${KERNEL_CFG}

${KERNEL_SRC}/README: ${KERNEL_SRC}.org/README
	rm -rf ${KERNEL_SRC}
	cp -a ${KERNEL_SRC}.org ${KERNEL_SRC}
	#cd ${KERNEL_SRC}; patch -p1 <../bootsplash-3.8.diff
	#cd ${KERNEL_SRC}; patch -p1 <../${RHKERSRCDIR}/patch-042stab083
	#cd ${KERNEL_SRC}; patch -p1 <../do-not-use-barrier-on-ext3.patch
	cd ${KERNEL_SRC}; patch -p1 <../bridge-patch.diff
	cd ${KERNEL_SRC}; patch -p1 <../bridge-forward-ipv6-neighbor-solicitation.patch
	cd ${KERNEL_SRC}; patch -p1 <../kvmstealtime.patch
	#cd ${KERNEL_SRC}; patch -p1 <../kvm-fix-invalid-secondary-exec-controls.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-aspm-policy.patch
	#cd ${KERNEL_SRC}; patch -p1 <../kbuild-generate-mudules-builtin.patch
	#cd ${KERNEL_SRC}; patch -p1 <../add-tiocgdev-ioctl.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-nfs-block-count.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-idr-header-for-drbd-compilation.patch
	cd ${KERNEL_SRC}; patch -p1 <../add-empty-ndo_poll_controller-to-veth.patch
	# cd ${KERNEL_SRC}; patch -p1 <../override_for_missing_acs_capabilities.patch
	cd ${KERNEL_SRC}; patch -p1 <../vhost-net-extend-device-allocation-to-vmalloc.patch
	cp ${KERNEL_SRC}/drivers/vhost/scsi.c ${KERNEL_SRC}/drivers/vhost/scsi.c.backup	
	# vhost-scsi compile fixes
	cd ${KERNEL_SRC}; patch -p1 <../vhost-scsi-fixes.patch
	sed -i ${KERNEL_SRC}/Makefile -e 's/^EXTRAVERSION.*$$/EXTRAVERSION=${EXTRAVERSION}/'
	touch $@

${KERNEL_SRC}.org/README: ${RHKERSRCDIR}/kernel.spec ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.xz
	rm -rf ${KERNEL_SRC}.org linux-${KERNEL_VER}-${RHKVER}
	tar xf ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.xz
	mv linux-${KERNEL_VER}-${RHKVER} ${KERNEL_SRC}.org
	touch $@

${RHKERSRCDIR}/kernel.spec: ${KERNELSRCRPM}
	rm -rf ${RHKERSRCDIR}
	mkdir ${RHKERSRCDIR}
	cd ${RHKERSRCDIR};rpm2cpio ../${KERNELSRCRPM} |cpio -i
	touch $@

#rr272x_1x.ko: .compile_mark ${RR272XSRC}
#	rm -rf ${RR272XDIR}
#	tar xf ${RR272XSRC}
#	mkdir -p /lib/modules/${KVNAME}
#	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
#	make -C ${TOP}/${RR272XDIR}/product/rr272x/linux KERNELDIR=${TOP}/${KERNEL_SRC}
#	cp ${RR272XDIR}/product/rr272x/linux/$@ .

aacraid.ko: .compile_mark ${AACRAIDSRC}
	rm -rf ${AACRAIDDIR}
	mkdir ${AACRAIDDIR}
	cd ${AACRAIDDIR};tar xzf ../${AACRAIDSRC}
	cd ${AACRAIDDIR};rpm2cpio aacraid-${AACRAIDVER}.src.rpm|cpio -i
	cd ${AACRAIDDIR};tar xf aacraid_source.tgz
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	make -C ${TOP}/${KERNEL_SRC} M=${TOP}/${AACRAIDDIR} modules
	cp ${AACRAIDDIR}/aacraid.ko .

hpsa.ko hpsa: .compile_mark ${HPSASRC}
	rm -rf ${HPSADIR}
	tar xf ${HPSASRC}
	sed -i ${HPSADIR}/drivers/scsi/hpsa_kernel_compat.h -e 's/^\/\* #define RHEL7.*/#define RHEL7/'
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	make -C ${TOP}/${KERNEL_SRC} M=${TOP}/${HPSADIR}/drivers/scsi modules
	cp ${HPSADIR}/drivers/scsi/hpsa.ko hpsa.ko

e1000e.ko e1000e: .compile_mark ${E1000ESRC}
	rm -rf ${E1000EDIR}
	tar xf ${E1000ESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${E1000EDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${E1000EDIR}/src/e1000e.ko e1000e.ko

igb.ko igb: .compile_mark ${IGBSRC}
	rm -rf ${IGBDIR}
	tar xf ${IGBSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IGBDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${IGBDIR}/src/igb.ko igb.ko

ixgbe.ko ixgbe: .compile_mark ${IXGBESRC}
	rm -rf ${IXGBEDIR}
	tar xf ${IXGBESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IXGBEDIR}/src; make CFLAGS_EXTRA="-DIXGBE_NO_LRO" BUILD_KERNEL=${KVNAME}
	cp ${IXGBEDIR}/src/ixgbe.ko ixgbe.ko

i40e.ko i40e: .compile_mark ${I40ESRC}
	rm -rf ${I40EDIR}
	tar xf ${I40ESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${I40EDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${I40EDIR}/src/i40e.ko i40e.ko

bnx2.ko cnic.ko bnx2x.ko: ${BNX2SRC}
	rm -rf ${BNX2DIR}
	tar xf ${BNX2SRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${BNX2DIR}; make -C bnx2/src KVER=${KVNAME}
	cd ${BNX2DIR}; make -C bnx2x/src KVER=${KVNAME}
	cp `find ${BNX2DIR} -name bnx2.ko -o -name cnic.ko -o -name bnx2x.ko` .

arcmsr.ko: .compile_mark ${ARECASRC}
	rm -rf ${ARECADIR}
	mkdir ${ARECADIR}; cd ${ARECADIR}; unzip ../${ARECASRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${ARECADIR}; make -C ${TOP}/${KERNEL_SRC} SUBDIRS=${TOP}/${ARECADIR} modules
	cp ${ARECADIR}/arcmsr.ko arcmsr.ko

${SPL_MODULES}: .compile_mark ${SPLSRC}
	rm -rf ${SPLDIR}
	tar xf ${SPLSRC}
	cd ${SPLDIR}; ./autogen.sh
	cd ${SPLDIR}; ./configure --with-config=kernel --with-linux=${TOP}/${KERNEL_SRC} --with-linux-obj=${TOP}/${KERNEL_SRC}
	cd ${SPLDIR}; make
	cp ${SPLDIR}/module/spl/spl.ko spl.ko
	cp ${SPLDIR}/module/splat/splat.ko splat.ko

${ZFS_MODULES}: .compile_mark ${ZFSSRC}
	rm -rf ${ZFSDIR}
	tar xf ${ZFSSRC}
	cd ${ZFSDIR}; ./autogen.sh
	cd ${ZFSDIR}; ./configure --with-spl=${TOP}/${SPLDIR} --with-spl-obj=${TOP}/${SPLDIR} --with-config=kernel --with-linux=${TOP}/${KERNEL_SRC} --with-linux-obj=${TOP}/${KERNEL_SRC}
	cd ${ZFSDIR}; make
	cp ${ZFSDIR}/module/zfs/zfs.ko zfs.ko
	cp ${ZFSDIR}/module/avl/zavl.ko zavl.ko
	cp ${ZFSDIR}/module/nvpair/znvpair.ko znvpair.ko
	cp ${ZFSDIR}/module/unicode/zunicode.ko zunicode.ko
	cp ${ZFSDIR}/module/zcommon/zcommon.ko zcommon.ko
	cp ${ZFSDIR}/module/zpios/zpios.ko zpios.ko


#iscsi_trgt.ko: .compile_mark ${ISCSITARGETSRC}
#	rm -rf ${ISCSITARGETDIR}
#	tar xf ${ISCSITARGETSRC}
#	cd ${ISCSITARGETDIR}; make KSRC=${TOP}/${KERNEL_SRC}
#	cp ${ISCSITARGETDIR}/kernel/iscsi_trgt.ko iscsi_trgt.ko

headers_tmp := $(CURDIR)/tmp-headers
headers_dir := $(headers_tmp)/usr/src/linux-headers-${KVNAME}

${HDR_DEB} hdr: .compile_mark headers-control.in headers-postinst.in
	rm -rf $(headers_tmp)
	install -d $(headers_tmp)/DEBIAN $(headers_dir)/include/
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <headers-control.in >$(headers_tmp)/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <headers-postinst.in >$(headers_tmp)/DEBIAN/postinst
	chmod 0755 $(headers_tmp)/DEBIAN/postinst
	install -D -m 644 copyright $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/copyright
	install -D -m 644 changelog.Debian $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	echo "git clone git://git.proxmox.com/git/pve-kernel-3.10.0.git\\ngit checkout ${GITVERSION}" > $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/SOURCE
	gzip -f --best $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	install -m 0644 ${KERNEL_SRC}/.config $(headers_dir)
	install -m 0644 ${KERNEL_SRC}/Module.symvers $(headers_dir)
	cd ${KERNEL_SRC}; find . -path './debian/*' -prune -o -path './include/*' -prune -o -path './Documentation' -prune \
	  -o -path './scripts' -prune -o -type f \
	  \( -name 'Makefile*' -o -name 'Kconfig*' -o -name 'Kbuild*' -o \
	     -name '*.sh' -o -name '*.pl' \) \
	  -print | cpio -pd --preserve-modification-time $(headers_dir)
	cd ${KERNEL_SRC}; cp -a include scripts $(headers_dir)
	cd ${KERNEL_SRC}; (find arch/x86 -name include -type d -print | \
		xargs -n1 -i: find : -type f) | \
		cpio -pd --preserve-modification-time $(headers_dir)
	dpkg-deb --build $(headers_tmp) ${HDR_DEB}
	#lintian ${HDR_DEB}

dvb-firmware.git/README:
	git clone https://github.com/OpenELEC/dvb-firmware.git dvb-firmware.git

linux-firmware.git/WHENCE:
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git linux-firmware.git

${FW_DEB} fw: control.firmware linux-firmware.git/WHENCE dvb-firmware.git/README changelog.firmware fwlist-2.6.18-2-pve fwlist-2.6.24-12-pve fwlist-2.6.32-3-pve fwlist-2.6.32-4-pve fwlist-2.6.32-6-pve fwlist-2.6.35-1-pve fwlist-2.6.32-13-pve fwlist-2.6.32-14-pve fwlist-2.6.32-20-pve fwlist-2.6.32-21-pve fwlist-3.10.0-3-pve fwlist-3.10.0-15-pve fwlist-${KVNAME}
	rm -rf fwdata
	mkdir -p fwdata/lib/firmware
	./assemble-firmware.pl fwlist-${KVNAME} fwdata/lib/firmware
	# include any files from older/newer kernels here
	./assemble-firmware.pl fwlist-2.6.24-12-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.18-2-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-3-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-4-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-6-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.35-1-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-13-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-14-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-20-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-21-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-3.10.0-3-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-3.10.0-15-pve fwdata/lib/firmware
	install -d fwdata/usr/share/doc/pve-firmware
	cp linux-firmware.git/WHENCE fwdata/usr/share/doc/pve-firmware/README
	install -d fwdata/usr/share/doc/pve-firmware/licenses
	cp linux-firmware.git/LICEN[CS]E* fwdata/usr/share/doc/pve-firmware/licenses
	install -D -m 0644 changelog.firmware fwdata/usr/share/doc/pve-firmware/changelog.Debian
	gzip -9 fwdata/usr/share/doc/pve-firmware/changelog.Debian
	echo "git clone git://git.proxmox.com/git/pve-kernel-2.6.32.git\\ngit checkout ${GITVERSION}" >fwdata/usr/share/doc/pve-firmware/SOURCE
	install -d fwdata/DEBIAN
	sed -e 's/@VERSION@/${FW_VER}-${FW_REL}/' <control.firmware >fwdata/DEBIAN/control
	dpkg-deb --build fwdata ${FW_DEB}

.PHONY: upload
upload: ${DST_DEB} ${HDR_DEB} ${FW_DEB}
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o rw 
	mkdir -p /pve/${RELEASE}/extra
	mkdir -p /pve/${RELEASE}/install
	rm -rf /pve/${RELEASE}/extra/${PACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/${HDRPACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/pve-firmware*.deb
	rm -rf /pve/${RELEASE}/extra/Packages*
	cp ${DST_DEB} ${FW_DEB} ${HDR_DEB} /pve/${RELEASE}/extra
	cd /pve/${RELEASE}/extra; dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o ro

.PHONY: distclean
distclean: clean
	rm -rf linux-firmware.git dvb-firmware.git ${KERNEL_SRC}.org ${RHKERSRCDIR}

.PHONY: clean
clean:
	rm -rf *~ .compile_mark ${KERNEL_CFG} ${KERNEL_SRC} tmp data proxmox-ve/data *.deb ${AOEDIR} aoe.ko ${headers_tmp} fwdata fwlist.tmp *.ko ${I40EDIR} ${IXGBEDIR} ${E1000EDIR} e1000e.ko ${IGBDIR} igb.ko fwlist-${KVNAME} ${BNX2DIR} bnx2.ko cnic.ko bnx2x.ko aacraid.ko ${AACRAIDDIR} rr272x_1x.ko ${RR272XDIR} ${ARECADIR}.ko ${ARECADIR} ${ZFSDIR} ${SPLDIR} ${SPL_MODULES} ${ZFS_MODULES} hpsa.ko ${HPSADIR}





