# Git branching (code branching) method

## Contents

- [Git branching (code branching) method](#git-branching-(code-branching)-method)
  - [Contents](#contents)
  - [Code contribution](#code-contribution)
  - [Forking and Branching Strategies](#forking-and-branching-strategies)
  - [Snowflake Community of Practice Branching Strategy](#snowflake-community-of-practice-branching-strategy)
  - [Workflow](#workflow)
    - [Typical feature workflow](#typical-feature-workflow)

## Code contribution

_The below is taken from [The Standard Team (Github)](https://github.com/hassanhabib/The-Standard-Team/blob/main/4%20Practices/4%20Practices.md)_

Defining a contribution guideline is crucial for any open-source or collaborative software development project.

It establishes clear rules and expectations for how contributors should submit and review changes, which helps to ensure that all contributions are made in a consistent and organized manner.

Additionally, a contribute guideline can provide guidance on best practices for coding, testing and documentation, which can help to improve the overall quality of the codebase.

It also serves as an educational tool to new contributors, providing them with the necessary information and instructions on how to contribute to the project effectively.

(Furthermore, having a well-defined GitHub contribute guideline can help to attract new contributors and maintain a healthy open-source community.)

## Forking and Branching Strategies

_The below is taken from [The Standard Team (Github)](https://github.com/hassanhabib/The-Standard-Team/blob/main/4%20Practices/4%20Practices.md)_

A branch strategy for code is essential for maintaining a stable and maintainable codebase.

It allows for multiple developers to work on different features or bug fixes simultaneously, without interfering with each other's work.

Each developer can create their own branch to work on, which can then be merged into the main branch once it has been reviewed and approved.

This helps to avoid conflicts, and ensures that the codebase remains stable and consistent.

Furthermore, a branch strategy enables version control and allows different versions of the codebase to be created and tracked.

This can be useful for rolling back changes if necessary, and for maintaining multiple versions of the software for different environments.

Overall, a branch strategy is a critical aspect of any software development project and is essential for ensuring that the codebase remains stable and maintainable.

There are several different types of branching strategies that can be used in software development, including:

1. **Gitflow**: A popular branching strategy that follows a strict branching model, where development happens in feature branches and is merged into a main development branch. This strategy is good for large projects with many contributors.

1. **Trunk-Based Development**: This strategy involves working on the main branch, or trunk, and committing changes directly to it. This is a good strategy for smaller projects with a small number of contributors.

1. **Feature Branching**: This strategy involves creating a separate branch for each feature or bug fix, and merging it into the main branch when it is complete. This is a good strategy for larger projects with multiple contributors.

1. **Forking**: This strategy involves creating a copy of the repository and working on it separately. This is good for open-source projects where multiple contributors are working on the same codebase.  The main advantage of the Forking workflow is that contributions can be integrated without the need for everybody to push to a single central repository. Developers push to their own server-side repositories, and only the project maintainer can push to the official repository. This allows the maintainer to accept commits from any developer without giving them write access to the official codebase.

1. **Release Branching**: This strategy involves creating a separate branch for each release, and merging it into the main branch when it is ready to be released. This is a good strategy for projects that have a regular release schedule.

1. **Continuous Integration**: This strategy involves merging code changes as soon as they are made, and running automated tests to ensure that the codebase remains stable. This is a good strategy for projects that have a high frequency of changes.

Ultimately, it's important to choose a branching strategy that fits the needs and constraints of the project, and that can be easily understood and followed by all the contributors.

## Snowflake Community of Practice Branching Strategy

As the Snowflake Community of Practice will not be a deployable repository the branching naming will not be required to adhere to standard conventions. Instead we will use the branching patterns that allow us to work collaboratively on elements of the community and maintain ongoing changes to different aspects of the shared learning in tandem.

Our branching naming approach has the following main categories:

| branch category | description |
| :--- | :--- |
| `main` | this acts as our core branch that must always contain correct and approved information. It must never be in a 'work in progress' state and be fully approved |
| `content` | these are generic branches for adding a multiple array of content types to the community |
| `snowsight-tips` branches | these are a series of branches for adding a "tip" to the collective community |
| `basics` branches | these are a series of branches for adding information about basic features of snowflake |
| `native-features` branches | These branches are to hold details of native features of Snowflake that are of particular use in NHS analytical situations |
| `contribution` branches | These are branches relating to changes in the contribution guide oor collaboration policies, as well as to the home readme |
| `policy` branches | These are branches for adding changes to conventions and policies for your organisation within the wider community. |
| `fix` branches | for bug fixes or corrections (e.g., fix/typo-in-warehouse-guide) |
| `update` branches | for updating existing content as a result of new information, or due to changes made by the Snowflake service |

## Workflow

### Typical feature workflow

The below outlines the typical workflow of a feature

1. A developer creates a branch from the main branch. The name of the branch will be prefixed with one of the above categories, followed by "/" and the users name and a brief title. An example could be `basics/BillWood-accessing-snowflake`
1. This branch is worked on by the author, adding commits to the branch to adjust code, adding or removing artefacts etc.
1. If the branch has been worked on for a number of days, it is prudent for the developer to rebase their branch before raising a request to merge their changes into main (via a pull request) and to first pull down changes that have been merged into the main branch since the branch was created. This will allow the developer to deal with conflicts in the code that have arisen due to changes since they began their work
1. When ready to do so, the developer/author can choose to raise a pull request to merge their changes into the main branch.
1. The pull request into the main branch is peer-reviewed; ensuirng that the content is fit to be added into the main branch. 
1. Upon approval, the code from the branch is merged into the main branch.

> [!TIP] 
> As noted above,  if the feature is a long running development, it is recommended that the feature branch is rebased from main to ensure that any changes are brought in and the feature remains in a working state / conflicts are resolved before raising the pull request._
