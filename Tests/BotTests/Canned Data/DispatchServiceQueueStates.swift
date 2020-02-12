import Foundation

let DispatchServiceQueueStatesJSON: Data = """
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


let DispatchServiceQueueStatesString = """
## Merge Queue for target branch: branch1 ##

State(
 - status: integrating PR #1 (some-branch),
 - queue:\(" ")
      1. PR #2 (abcdef)
)

## Merge Queue for target branch: branch2 ##

State(
 - status: integrating PR #3 (abcdef),
 - queue: []
)
"""
