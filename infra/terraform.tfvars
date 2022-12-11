prefix          = "gke-poc"
billing_account = "01504C-A2522F-2110FA"
folder_id       = "folders/879011168459"
region          = "europe-west1"

clusters = [
  {
    name              = "cl1"
    location          = "europe-west1"
    master_cidr_block = "172.16.0.0/28"
    cp-auth-networks = [
      {
        cidr_block = "10.0.0.0/8"
        name       = "all"
      },
    ]
  },
  {
    name              = "cl2"
    location          = "europe-west6"
    master_cidr_block = "172.16.0.16/28"
    cp-auth-networks = [
      {
        cidr_block = "10.0.0.0/8"
        name       = "all"
      },
    ]
  },
]
