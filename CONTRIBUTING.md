# Contributing

Keep this module small and opinionated. Explain the threat, resulting AWS/Kubernetes behavior, compatibility impact and residual limits for each control change. Use a branch and pull request; require the verification workflow before merge. Add an input rejection or composed-resource assertion for meaningful security behavior, and a source mutation when it would catch a plausible regression.

Run the README checks. For admission changes, run the disposable kind test. Never add AWS credentials, state, raw deployment plans, backend settings or real workload data. CI must remain credential-free and must not deploy infrastructure. Use exact module revisions, full action SHAs and reviewed tool checksums; do not add automatic approval, auto-merge or cloud deployment steps.

Releases follow semantic versioning. During 0.x, a minor release may change module interfaces; patch releases fix compatible behavior. Changes to access scope, PSA versions, DNS/CNI configuration, IAM trust, providers or state ownership require explicit migration notes. A maintainer publishes a tag/release only after all checks pass and includes checksums and evidence. Changes to dependency versions must be tested rather than justified by a green dependency bot alone.
