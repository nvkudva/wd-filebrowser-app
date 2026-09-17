# TODO

- [ ] Make File Browser a proper WD dashboard app with a tile (Go-to-app + Uninstall)
  - Blocker: OS 5 `apkg` daemon rebuilds the app list from a signature-verified store
    and drops any manually-injected entry. See README "Why there's no app tile".
  - Explore:
    - [ ] Whether `module_sign_flag` can be toggled to accept unsigned manual uploads,
          and the exact security tradeoff of doing so.
    - [ ] Recover/understand the Blowfish key flow (`openssl bf-cbc -d -k`) used for
          `apkg.sign` — for understanding only, not to forge WD packages.
    - [ ] Current (2026) state of the WD/SanDisk third-party app / developer program.
    - [ ] Reverse-proxy the app under the WD web root so at least a bookmarkable
          in-dashboard link exists without a signed package.
