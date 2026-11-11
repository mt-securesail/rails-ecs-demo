# Every response tells caches not to store it: not shared caches (proxies,
# CDNs) and not the browser. Pages are dynamic, and once there are logins they
# will hold per-user data that must never be served to someone else.
# (A request, not a guarantee: anyone who receives a page can still save it.)
#
# Done as middleware at the very start of the stack, so it runs last on the way
# out and covers every response (pages, /up, 404s, errors), overriding Rails'
# default "max-age=0, private, must-revalidate".
# Related to ZAP rule 10049 (accepted, see .zap/rules.tsv); enforced by
# test/security/security_headers_test.rb.
class NoStoreMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers["cache-control"] = "no-store"
    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before 0, NoStoreMiddleware
