## SNTP v0.2.2 May 31, 2021

### Bug Fixes

* Fix bug that prevented usage on Elixir `v1.12`.

## SNTP v0.2.1 July 20, 2018

### Bug Fixes

* Fix bug that prevented the retriever to start via mix config.

## SNTP v0.2.0 June 17, 2018

### Bug Fixes

* Fix calculation bug there resulted in invalid timestamp

### Breaking Changes

* `time/1` now return `{:ok, %Timestamp{}}` or `{:error, [{error, reason} ...]}`
* `time!/1` has been removed use `time/1`
* `offset/0` now retrun `{:ok, integer()}` or `{:error, {RetriverError, "SNTP Retriver is not started"}}` when the `SNTP.Retriver` hasn't been started
* `now/1` if the `SNTP.Retriver` is started it will now the calculated system time with the retrieved offset.

### Enhancements

* `start/1` starts the `SNTP.Retriever` which periodically receives an NTP timestamp. defaults to every 24 hours
* `stop/1`  stops the `SNTP.Retriever`


## SNTP v0.1.0 September 1, 2017

### Enhancements

* Initial
