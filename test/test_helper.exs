# No connection pooling in the test suite.
#
# Bypass listens with SO_REUSEPORT, so a test's server can end up sharing a port with a
# previous test's server that is still shutting down. A keep-alive connection kept in
# hackney's pool is then reused for the new test's request and lands on the old server,
# whose routes are gone, and comes back as a bare 404 — failing an innocent REST test about
# one run in ten. It surfaced with hackney 4, which pools more eagerly than 1.x.
#
# This is a property of running many local servers on shared ports, not of production: EDA
# only ever talks to discord.com, where reusing connections is exactly what should happen.
# So pooling is switched off here and nowhere else. hackney reads this on every request.
Application.put_env(:hackney, :use_default_pool, false)

ExUnit.start()
