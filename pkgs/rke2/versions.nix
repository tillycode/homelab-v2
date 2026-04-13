{
  rke2Version = "1.35.3+rke2r3";
  rke2Commit = "b875dde727128d4ea23e0f4bcc0588341e89358a";
  rke2TarballHash = "sha256-ROfNkBdx5X9Ua4SHsrYA75tjUGF7XAPRFWhoveUBuGA=";
  rke2VendorHash = "sha256-aidDNxmTA7VJ84ld+x7oS4j8aeEUEpIs/cflRVRyHJM=";
  k8sImageTag = "v1.35.3-rke2r3-build20260407";
  etcdVersion = "v3.6.7-k3s1-build20260227";
  pauseVersion = "3.6";
  ccmVersion = "v1.35.1-0.20260211145923-50fa2d70c239-build20260211";
  dockerizedVersion = "v1.35.3-rke2r3";
  helmJobVersion = "v0.9.14-build20260309";
  imagesVersions = with builtins; fromJSON (readFile ./images-versions.json);
}
