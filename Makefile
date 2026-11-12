# 在仓库根目录使用。build / run / update 都面向 macOS。
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: build run update

build:
	bash "$(ROOT)/build.sh"

run: build
	bash "$(ROOT)/scripts/restart-app.sh" "$(ROOT)/build/SalaryCounter.app"

update:
	bash "$(ROOT)/scripts/update.sh"
