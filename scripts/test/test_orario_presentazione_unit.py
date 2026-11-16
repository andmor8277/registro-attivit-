from app.routers.partite import _default_ora_presentazione as f

casi = [
    ("15:00", "casa", "14:15"),
    ("15:00", "fuori", "14:00"),
    ("09:30", "casa", "08:45"),
    ("09:30", "fuori", "08:30"),
    ("16:45", "CASA", "16:00"),
    ("16:45", "fuori ", "15:45"),
    ("00:20", "casa", "00:00"),
    ("15:00:00", "casa", "14:15"),
    (None, "casa", None),
    ("", "fuori", None),
    ("non-ora", "casa", None),
    ("25:00", "casa", None),
    ("15:60", "casa", None),
    ("15:00", None, "14:15"),
]

ok = ko = 0
for ora, cf, atteso in casi:
    got = f(ora, cf)
    if got == atteso:
        ok += 1
        print("  ok    %-10r %-9r -> %r" % (ora, cf, got))
    else:
        ko += 1
        print("  FAIL  %-10r %-9r -> %r (atteso %r)" % (ora, cf, got, atteso))

print("  %d passati, %d falliti" % (ok, ko))
raise SystemExit(1 if ko else 0)
