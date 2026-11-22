# Let WebMock intercept httpx requests (httpx ships the adapter).
require "httpx/adapters/webmock"
WebMock.enable!
