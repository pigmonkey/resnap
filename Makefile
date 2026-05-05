PREFIX  = /usr/local
BINDIR  = $(PREFIX)/bin
CONFDIR = $(PREFIX)/etc/resnap

.PHONY: install uninstall

install:
	install -m 755 -d $(BINDIR)
	sed 's|/usr/local/etc/resnap|$(CONFDIR)|g' resnap > $(BINDIR)/resnap
	chmod 755 $(BINDIR)/resnap
	sed 's|/usr/local/etc/resnap|$(CONFDIR)|g' resnap-restore > $(BINDIR)/resnap-restore
	chmod 755 $(BINDIR)/resnap-restore
	install -m 755 -d $(CONFDIR)
	for f in drives excludes restore; do \
		test -f $(CONFDIR)/$$f || install -m 644 $$f $(CONFDIR)/$$f; \
	done
	test -f $(CONFDIR)/password || install -m 600 /dev/null $(CONFDIR)/password

uninstall:
	rm -f $(BINDIR)/resnap $(BINDIR)/resnap-restore
