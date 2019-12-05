import Foundation

let DispatchServiceQueueStates: Data = """
[
  {
    "targetBranch" : "branch1",
    "status" : {
      "status" : "integrating",
      "metadata" : {
        "mergeable_state" : "behind",
        "reference" : {
          "head" : {
            "ref" : "some-branch",
            "sha" : "abcdef"
          },
          "number" : 1,
          "title" : "Best Pull Request",
          "labels" : [
            {
              "name" : "Please Merge 🙏"
            }
          ],
          "base" : {
            "ref" : "branch1",
            "sha" : "abc"
          },
          "user" : {
            "login" : "John Doe"
          }
        },
        "merged" : false
      }
    },
    "queue" : [
      {
        "head" : {
          "ref" : "abcdef",
          "sha" : "abcdef"
        },
        "number" : 2,
        "title" : "Best Pull Request",
        "labels" : [
          {
            "name" : "Please Merge 🙏"
          }
        ],
        "base" : {
          "ref" : "branch1",
          "sha" : "abc"
        },
        "user" : {
          "login" : "John Doe"
        }
      }
    ]
  },
  {
    "targetBranch" : "branch2",
    "status" : {
      "status" : "integrating",
      "metadata" : {
        "mergeable_state" : "behind",
        "reference" : {
          "head" : {
            "ref" : "abcdef",
            "sha" : "abcdef"
          },
          "number" : 3,
          "title" : "Best Pull Request",
          "labels" : [
            {
              "name" : "Please Merge 🙏"
            }
          ],
          "base" : {
            "ref" : "branch2",
            "sha" : "abc"
          },
          "user" : {
            "login" : "John Doe"
          }
        },
        "merged" : false
      }
    },
    "queue" : [

    ]
  }
]
""".data(using: .utf8)!
