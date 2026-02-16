zones = {
  "szp15.com" = {
    records = {
      hgh0_a    = { name = "hgh0", type = "A", content = "47.96.145.133" }
      hgh0_aaaa = { name = "hgh0", type = "AAAA", content = "2408:4005:3cd:1440:87e:2da4:1f5d:d761" }
      cache     = { name = "cache", type = "CNAME", content = "hgh0.szp15.com" }
      file      = { name = "file", type = "CNAME", content = "hgh0.szp15.com" }
      downloads = { name = "downloads", type = "CNAME", content = "szpio-cloudreve-storage.oss-cn-hangzhou.aliyuncs.com" }
      firefly   = { name = "firefly", type = "CNAME", content = "hgh0.szp15.com" }
      login     = { name = "login", type = "CNAME", content = "hgh0.szp15.com" }
      mc        = { name = "mc", type = "CNAME", content = "hgh0.szp15.com" }
      tailnet   = { name = "tailnet", type = "CNAME", content = "hgh0.szp15.com" }
      "@"       = { name = "@", type = "CNAME", content = "hgh0.szp15.com" }

      ingress1 = { name = "ingress", type = "A", content = "47.96.145.133" }
      whoami   = { name = "whoami", type = "CNAME", content = "ingress.szp15.com" }
    }
  }

  "eh578599.xyz" = {
    records = {
      hkg0 = { name = "hkg0", type = "A", content = "87.83.107.23" }
      hkg1 = { name = "hkg1", type = "A", content = "194.104.147.179" }
      sjc0 = { name = "sjc0", type = "A", content = "185.218.6.162" }
    }
  }

  "szp.io" = {
    records = {
      "@_mx1" = { name = "@", type = "MX", content = "mx1.feishu.cn", priority = 1 }
      "@_mx2" = { name = "@", type = "MX", content = "mx2.feishu.cn", priority = 5 }
      "@_mx3" = { name = "@", type = "MX", content = "mx3.feishu.cn", priority = 10 }
      "spf"   = { name = "@", type = "TXT", content = "\"v=spf1 +include:_netblocks.m.feishu.cn -all\"" }
      "dkim" = {
        name    = "feishu2602170023._domainkey",
        type    = "TXT",
        content = "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwK4c8gdzkCTS0keaXuBPtDMLWYjfd6fp8fcwnYY+X6kn+2N+MdUD5LDmKrMtOn3O4XoQCVRpX0ewn6wrctNYEFzaTZslQqZNJiCGIxDuP7ajCF6lewtmyT0ATjnHyP4L0ONA5jXe6gPVzkmFCAi0oOpdMUEQejT+9UPVHwSLbDhY9U8Py0NG3ezVKz6X5BYh/\" \"DtZcuCFrbPCMoUS8tUHADUu1A3+vtgBMeA5lE20DF5hptAWsRuBOKE4Yfre7UKM/PRHLJ7gd13RrFDsKXz/NPEmvg0fwoubF45lzRhieAE2o5i9f3Ht76Xniz4tCgcBnvu5d/sCiy5kp+SuxB7Y/wIDAQAB\""
      }
      "dmarc" = {
        name    = "_dmarc",
        type    = "TXT",
        content = "\"v=DMARC1; p=quarantine; pct=100; ruf=mailto:me@szp.io; rua=mailto:me@szp.io\""
      }
    }
  }
}
