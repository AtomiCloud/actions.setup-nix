## [2.5.1](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.5.0...v2.5.1) (2025-06-25)


### 🐛 Bug Fixes 🐛

* correct use attic substituters ([e463bb9](https://github.com/AtomiCloud/actions.setup-nix/commit/e463bb965bcbfb94205ea0b661719c1da265ef12))

## [2.5.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.4.0...v2.5.0) (2025-06-17)


### 🐛 Bug Fixes 🐛

* incorrect workflow wait ([7672a6c](https://github.com/AtomiCloud/actions.setup-nix/commit/7672a6ca29b917ef294f2434ed746f829b5b0d62))
* use non-namespacelabs version for macos ([d385c6f](https://github.com/AtomiCloud/actions.setup-nix/commit/d385c6ffa32da3a74789846d41c29fc04e47eab0))


### ✨ Features ✨

* allow using attic token ([fcc736d](https://github.com/AtomiCloud/actions.setup-nix/commit/fcc736d415125566270b3a931c4c45d9e91c3376))
* cache nix shells ([234adf0](https://github.com/AtomiCloud/actions.setup-nix/commit/234adf03dd94efc61b403a3a97fb11767459c249))
* only push shells on tag release ([8374be1](https://github.com/AtomiCloud/actions.setup-nix/commit/8374be17d8511dabaf8d9bc08b716412786beba3))
* use substituters directly ([302cad0](https://github.com/AtomiCloud/actions.setup-nix/commit/302cad08064faffecfb90783e6fe5db99ea279b3))

## [2.4.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.3.0...v2.4.0) (2025-04-13)


### ✨ Features ✨

* **default:** migrate to atomiutils from coreutils ([#8](https://github.com/AtomiCloud/actions.setup-nix/issues/8)) ([0db2657](https://github.com/AtomiCloud/actions.setup-nix/commit/0db26573bc3e3c49c7f51404092402a290c46f38))
* **default:** migrate to atomiutils from coreutils ([dbafc15](https://github.com/AtomiCloud/actions.setup-nix/commit/dbafc159799110d1b9a41499f4cecbd07c1656e9))

## [2.3.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.2.0...v2.3.0) (2025-04-13)


### ✨ Features ✨

* **default:** upgrade to use authbot to allow ruleset ([#7](https://github.com/AtomiCloud/actions.setup-nix/issues/7)) ([19187dc](https://github.com/AtomiCloud/actions.setup-nix/commit/19187dc843fa38f9c97b4149b4105101c11c304c))
* **default:** upgrade to use authbot to allow ruleset ([a9c067b](https://github.com/AtomiCloud/actions.setup-nix/commit/a9c067b81a06d7d0fa52bbe943cbe53e99a44643))

## [2.2.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.1.0...v2.2.0) (2025-04-13)


### 🐛 Bug Fixes 🐛

* **action:** allow weak pin on gha ([667e11a](https://github.com/AtomiCloud/actions.setup-nix/commit/667e11a9dbbf861346753246b523eccd3157a6cc))
* **action:** checkout git repository ([#6](https://github.com/AtomiCloud/actions.setup-nix/issues/6)) ([e115d07](https://github.com/AtomiCloud/actions.setup-nix/commit/e115d079e2bff6e3330f68397da40b871f2c5123))
* **action:** checkout git repository ([e1c5219](https://github.com/AtomiCloud/actions.setup-nix/commit/e1c5219a655aefd94ccebac23bf91589c10666f0))
* **action:** temporarily depend on v1 ([5380e20](https://github.com/AtomiCloud/actions.setup-nix/commit/5380e201d5b4ea745f77d1f896386fa9683048e6))
* **action:** upgrade to v2 setup-nix ([885c6e7](https://github.com/AtomiCloud/actions.setup-nix/commit/885c6e78e182f4a11e9d6e298fa08c1f0b571916))


### ✨ Features ✨

* **ci:** switch to using rulesets for CI ([#5](https://github.com/AtomiCloud/actions.setup-nix/issues/5)) ([988a0a2](https://github.com/AtomiCloud/actions.setup-nix/commit/988a0a2291e19b8c921b5cd1922480945540b6ae))
* **ci:** switch to using rulesets for CI ([d80bfe1](https://github.com/AtomiCloud/actions.setup-nix/commit/d80bfe1e2628ce968c882ec4a1a1cc9c7bc122d6))

## [2.1.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v2.0.0...v2.1.0) (2025-04-12)


### ✨ Features ✨

* **default:** allow not using auth-bot ([#4](https://github.com/AtomiCloud/actions.setup-nix/issues/4)) ([398d69c](https://github.com/AtomiCloud/actions.setup-nix/commit/398d69c95fae7cd8b2cfb23afe89a9d1538ce096))
* **default:** allow not using auth-bot ([b992c45](https://github.com/AtomiCloud/actions.setup-nix/commit/b992c455aa51a9bdede24ed47bcb1cc6c49aa448))

## [2.0.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.3.2...v2.0.0) (2025-03-23)


### 🐛 Bug Fixes 🐛

* added input check for native ([9abbf76](https://github.com/AtomiCloud/actions.setup-nix/commit/9abbf769c5b22e00042c01ca07c278cc7e678a60))
* commented out namespace lab checkout ([8d94232](https://github.com/AtomiCloud/actions.setup-nix/commit/8d942329450bd5fc10cdc7e578f9da74491e4ed4))
* removed namespace labs if checks from action ([6da1f3c](https://github.com/AtomiCloud/actions.setup-nix/commit/6da1f3cce31fca46800cf073d4c8421c8018e948))
* removed namespace labs inputs ([5904466](https://github.com/AtomiCloud/actions.setup-nix/commit/5904466b1f170d038535c2734e5ad3c6dac47d6c))
* renamed local_action ([fd15ced](https://github.com/AtomiCloud/actions.setup-nix/commit/fd15cedce2a0cd87bb7d5ce5e1ed71834816eb93))


### ✨ Features ✨

* added token gen to action to allow auth-bot commits on main ([#3](https://github.com/AtomiCloud/actions.setup-nix/issues/3)) ([27fd36a](https://github.com/AtomiCloud/actions.setup-nix/commit/27fd36af082d42ad46347a067ba1ad4e04e82485))
* added token gen to allow auth-bot code commits on protected branch ([98e8bc3](https://github.com/AtomiCloud/actions.setup-nix/commit/98e8bc3cdd4fd7d522a34a9de0f8576cc90d44db))


### 🗑️ Removed 🗑

* removed namespacelab checkout action ([f236960](https://github.com/AtomiCloud/actions.setup-nix/commit/f236960ff3cd4d8b21abc7fbd1677883a587b619))

## [1.3.2](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.3.1...v1.3.2) (2025-03-04)


### 🐛 Bug Fixes 🐛

* **default:** remove deprecated magic nix cache ([cd7058e](https://github.com/AtomiCloud/actions.setup-nix/commit/cd7058e2971277e90918e43c80383fbbac72c64c))


### 📝 Documentation Updates 📝

* better description for short-length ([102b423](https://github.com/AtomiCloud/actions.setup-nix/commit/102b42370190aa1038486ca795c09a017b87e488))

## [1.3.1](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.3.0...v1.3.1) (2025-01-28)


### 🐛 Bug Fixes 🐛

* incorrect short-length propogation ([2aeff6c](https://github.com/AtomiCloud/actions.setup-nix/commit/2aeff6c1b6bfcd5503b3c91e758dcb9428235a43))

## [1.3.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.2.1...v1.3.0) (2025-01-27)


### 🐛 Bug Fixes 🐛

* allow major and minor tags to be published ([af8b03e](https://github.com/AtomiCloud/actions.setup-nix/commit/af8b03e9949f45b40251b53c5c58a7ab13e43484))


### ✨ Features ✨

* pinned to major, added slug action ([34f2869](https://github.com/AtomiCloud/actions.setup-nix/commit/34f2869557c42058dc67db0bce3bd92ff0ef9dd3))
* update actions to latest release ([0459029](https://github.com/AtomiCloud/actions.setup-nix/commit/04590295d778d368c8976e34ee25645a46aadfb6))
* upgrade infrastructure ([75081e9](https://github.com/AtomiCloud/actions.setup-nix/commit/75081e9ac73fa887007e0b1a48986dcb0e633b22))

## [1.2.1](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.2.0...v1.2.1) (2024-02-24)


### 🐛 Bug Fixes 🐛

* force bump ([c34aa3d](https://github.com/AtomiCloud/actions.setup-nix/commit/c34aa3da3e39bf08b909577b68a06ac294f8e5d5))

## [1.2.0](https://github.com/AtomiCloud/actions.setup-nix/compare/v1.1.0...v1.2.0) (2024-02-24)


### 🐛 Bug Fixes 🐛

* incorrect actions ([13bc595](https://github.com/AtomiCloud/actions.setup-nix/commit/13bc5957056a78d3529c3558e5add5a9c9d654da))
* incorrect actions ([82fa615](https://github.com/AtomiCloud/actions.setup-nix/commit/82fa6158e112bbbfd85ae7e073f217adc14cb3da))
* incorrect actions ([8c2bca8](https://github.com/AtomiCloud/actions.setup-nix/commit/8c2bca8a8dbbad7255cdf1e119a8c4da1b64728e))


### ✨ Features ✨

* use different cache key for releaser ([1f33900](https://github.com/AtomiCloud/actions.setup-nix/commit/1f33900f4e7d7e836d6cbef206653df476d23725))

## [1.1.0](https://github.com/AtomiCloud/action.setup-nix/compare/v1.0.0...v1.1.0) (2024-02-24)


### ✨ Features ✨

* initial commit ([7313ab1](https://github.com/AtomiCloud/action.setup-nix/commit/7313ab18bc62ebd1e86080afbcfbc0e5238f9c03))


### 📝 Documentation Updates 📝

* improve docs for readme ([956b622](https://github.com/AtomiCloud/action.setup-nix/commit/956b622d96e77e77e1d05e1568bd9395ae7efb2a))

## 1.0.0 (2024-02-24)


### ✨ Features ✨

* initial commit ([68d440a](https://github.com/AtomiCloud/action.setup-nix/commit/68d440a15f147cd4fbe13be5a60cdd0ec3b1c93d))

## [1.2.0](https://github.com/AtomiCloud/atomici-ns-action/compare/v1.1.0...v1.2.0) (2024-02-24)


### 🐛 Bug Fixes 🐛

* incorrect if expressions ([670f836](https://github.com/AtomiCloud/atomici-ns-action/commit/670f836669bda1df9e7383b9a559c854a6723bf6))


### ✨ Features ✨

* upgrade to use self for CI ([5f5c966](https://github.com/AtomiCloud/atomici-ns-action/commit/5f5c9669a7bbf3a9eb6bb489d5c30afb60d24627))

## [1.1.0](https://github.com/AtomiCloud/atomici-ns-action/compare/v1.0.0...v1.1.0) (2024-02-24)


### 🐛 Bug Fixes 🐛

* incorrect condition expression ([dbc5d7b](https://github.com/AtomiCloud/atomici-ns-action/commit/dbc5d7b88a7b1363f519604e435d979b3a6decd0))


### ✨ Features ✨

* update branding and self-use ([303e18e](https://github.com/AtomiCloud/atomici-ns-action/commit/303e18ee75b43bd0867a9cd392dbc6d25b475caf))

## 1.0.0 (2024-02-24)


### 🐛 Bug Fixes 🐛

* formatting in release ([8f31290](https://github.com/AtomiCloud/atomici-ns-action/commit/8f31290e2579ec21f630f49bf676c59c74626f8b))


### ✨ Features ✨

* include checkout and native compatible ([383ae00](https://github.com/AtomiCloud/atomici-ns-action/commit/383ae00d1b7367b27ddfbfae4680f20e3d12d773))
* initial commit ([a50bc8c](https://github.com/AtomiCloud/atomici-ns-action/commit/a50bc8c06c80abbafe19c5141bc6545c6200c166))
