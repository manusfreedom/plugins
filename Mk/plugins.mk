# Copyright (c) 2015-2016 Franco Fichtner <franco@opnsense.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

all: check

LOCALBASE?=		/usr/local
PKG!=			which pkg || echo true

PLUGIN_DESC!=		git rev-list HEAD --max-count=1 | cut -c1-9
PLUGIN_SCRIPTS=		+PRE_INSTALL +POST_INSTALL \
			+PRE_DEINSTALL +POST_DEINSTALL

# Setting private mode allows plugins not
# to show up in the firmware GUI, and must
# thus be installed during build or console.
.if "${PLUGIN_PRIVATE}" == ""
PLUGIN_PREFIX=		os-
.else
PLUGIN_PREFIX=		ospriv-
.endif

PLUGIN_WWW?=		https://opnsense.org/
PLUGIN_REVISION?=	0

PLUGIN_REQUIRES=	PLUGIN_NAME PLUGIN_VERSION PLUGIN_COMMENT \
			PLUGIN_MAINTAINER

check:
.for PLUGIN_REQUIRE in ${PLUGIN_REQUIRES}
.  if "${${PLUGIN_REQUIRE}}" == ""
.    error "${PLUGIN_REQUIRE} not set"
.  endif
.endfor

.if "${PLUGIN_REVISION}" != "" && "${PLUGIN_REVISION}" != "0"
PLUGIN_PKGVERSION=	${PLUGIN_VERSION}_${PLUGIN_REVISION}
.else
PLUGIN_PKGVERSION=	${PLUGIN_VERSION}
.endif

name: check
	@echo ${PLUGIN_PREFIX}${PLUGIN_NAME}

depends: check
	@echo ${PLUGIN_DEPENDS}

manifest: check
	@echo "name: ${PLUGIN_PREFIX}${PLUGIN_NAME}"
	@echo "version: \"${PLUGIN_PKGVERSION}\""
	@echo "origin: opnsense/${PLUGIN_PREFIX}${PLUGIN_NAME}"
	@echo "comment: \"${PLUGIN_COMMENT}\""
	@echo "desc: \"${PLUGIN_DESC}\""
	@echo "maintainer: \"${PLUGIN_MAINTAINER}\""
	@echo "categories: [ \"${.CURDIR:S/\// /g:[-2]}\" ]"
	@echo "www: \"${PLUGIN_WWW}\""
	@echo "prefix: \"${LOCALBASE}\""
	@echo "licenselogic: \"single\""
	@echo "licenses: [ \"BSD2CLAUSE\" ]"
.if defined(PLUGIN_DEPENDS)
	@echo "deps: {"
	@for PLUGIN_DEPEND in ${PLUGIN_DEPENDS}; do \
		if ! ${PKG} query '  %n: { version: "%v", origin: "%o" }' \
		    $${PLUGIN_DEPEND}; then \
			echo ">>> Missing dependency: $${PLUGIN_DEPEND}" >&2; \
			exit 1; \
		fi; \
	done
	@echo "}"
.endif

scripts: check
	@for SCRIPT in ${PLUGIN_SCRIPTS}; do \
		if [ -f $${SCRIPT} ]; then \
			cp $${SCRIPT} ${DESTDIR}/; \
		fi; \
	done

install: check
	@mkdir -p ${DESTDIR}${LOCALBASE}
	@(cd ${.CURDIR}/src; find * -type f) | while read FILE; do \
		tar -C ${.CURDIR}/src -cpf - $${FILE} | \
		    tar -C ${DESTDIR}${LOCALBASE} -xpf -; \
	done

plist: check
	@(cd ${.CURDIR}/src; find * -type f) | while read FILE; do \
		echo ${LOCALBASE}/$${FILE}; \
	done

metadata: check
	@mkdir -p ${DESTDIR}
	@${MAKE} DESTDIR=${DESTDIR} scripts
	@${MAKE} DESTDIR=${DESTDIR} manifest > ${DESTDIR}/+MANIFEST
	@${MAKE} DESTDIR=${DESTDIR} plist > ${DESTDIR}/plist

collect: check
	@(cd ${.CURDIR}/src; find * -type f) | while read FILE; do \
		tar -C ${DESTDIR}${LOCALBASE} -cpf - $${FILE} | \
		    tar -C ${.CURDIR}/src -xpf -; \
	done

remove: check
	@(cd ${.CURDIR}/src; find * -type f) | while read FILE; do \
		rm -f ${DESTDIR}${LOCALBASE}/$${FILE}; \
	done
	@(cd ${.CURDIR}/src; find * -type d -depth) | while read DIR; do \
		if [ -d ${DESTDIR}${LOCALBASE}/$${DIR} ]; then \
			rmdir ${DESTDIR}${LOCALBASE}/$${DIR}; \
		fi; \
	done

WRKDIR?=${.CURDIR}/work
WRKSRC=	${WRKDIR}/src
PKGDIR=	${WRKDIR}/pkg

package: check
	@rm -rf ${WRKSRC} ${PKGDIR}
	@mkdir -p ${WRKSRC} ${PKGDIR}
	@${MAKE} DESTDIR=${WRKSRC} FLAVOUR=${FLAVOUR} metadata
	@${MAKE} DESTDIR=${WRKSRC} FLAVOUR=${FLAVOUR} install
	@${PKG} create -v -m ${WRKSRC} -r ${WRKSRC} \
	    -p ${WRKSRC}/plist -o ${PKGDIR}
	@echo -n "Sucessfully built "
	@cd ${PKGDIR}; find . -name "*.txz" | cut -c3-

mount: check
	mount_unionfs ${.CURDIR}/src ${DESTDIR}${LOCALBASE}

umount: check
	umount -f "<above>:${.CURDIR}/src"

clean: check
	@git reset -q . && git checkout -f . && git clean -xdqf .

lint: check
	find ${.CURDIR}/src \
	    -name "*.sh" -type f -print0 | xargs -0 -n1 sh -n
	find ${.CURDIR}/src \
	    -name "*.xml" -type f -print0 | xargs -0 -n1 xmllint --noout
	find ${.CURDIR}/src \
	    ! -name "*.xml" ! -name "*.xml.sample" ! -name "*.eot" \
	    ! -name "*.svg" ! -name "*.woff" ! -name "*.woff2" \
	    ! -name "*.otf" ! -name "*.png" ! -name "*.js" \
	    ! -name "*.scss" ! -name "*.py" ! -name "*.ttf" \
	    ! -name "*.tgz" ! -name "*.xml.dist" \
	    -type f -print0 | xargs -0 -n1 php -l


.PHONY:	check
