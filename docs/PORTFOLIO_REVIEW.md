# GitHub portfolio review — 2026-11-25

This review inspected accessible repository metadata, selected READMEs and selected source/configuration files. It is not a complete security or runtime audit of every repository. NutriCare's test suites and Android build were run separately.

## Public projects on this profile

| Repository | Observed scope | Suggested presentation |
|---|---|---|
| [NutriCare](https://github.com/sammihere2001/NutriCare) | Flutter/FastAPI/PostgreSQL nutrition-tracking prototype; source, screenshots, tests, Docker and Android demo | Lead mobile/API/data integration project; explain prototype and medical-review limits |
| [splitkaro](https://github.com/sammihere2001/splitkaro) | React/FastAPI expense-sharing application, settlement logic, Docker and GitHub Actions workflow | Strong full-stack web project; demonstrate auth, ownership and integer-money design |
| [MERN application](https://github.com/sammihere2001/MERN-STACK-REACT-node-js-mongodb-stripe) | Customer/admin React clients; Express/Mongoose food/cart/order/user routes; Stripe integration code | Show frontend/admin/API separation; README added; payment behavior not re-tested in this review |
| [Smart_Mart-SaimAzam](https://github.com/sammihere2001/Smart_Mart-SaimAzam) | Python/Tkinter retail GUI with MVC structure and file-backed storage | Supporting desktop/software-design project; do not call it a web full-stack app |
| [FALL-PF-2022](https://github.com/sammihere2001/FALL-PF-2022) | Programming-fundamentals coursework | Keep as learning history rather than a lead portfolio pin |
| [Lab11](https://github.com/sammihere2001/Lab11) | Small lab repository | Supporting coursework |
| [TkCalculator-65383](https://github.com/sammihere2001/TkCalculator-65383) | Small Tkinter calculator | Supporting Python GUI exercise |
| [WaterReminder-65383](https://github.com/sammihere2001/WaterReminder-65383) | Small Python reminder utility | Supporting utility; README exists |
| [Programming-Fundamentals](https://github.com/sammihere2001/Programming-Fundamentals) | Empty repository at review | Do not feature until it contains reviewable work |
| [SDA-Proj](https://github.com/sammihere2001/SDA-Proj) | Empty repository at review | Do not feature until it contains reviewable work |

The new `sammihere2001` repository supplies the GitHub profile README. Existing private repositories were not made public as part of this review except NutriCare, which the owner explicitly requested.

## Frontend collaboration

The user confirmed frontend work on [IntelliChat](https://github.com/MominKhan9/intellchat-ai-context-aware-reply-assistant) and [Parking Lot Management System](https://github.com/MominKhan9/Parking-lot-management-system). Both are public repositories owned by MominKhan9, and the account has collaborator access. The profile README links them with that limited role; it does not claim sole authorship or backend ownership.

An additional accessible collaboration, `Musfirabano12/ExpenseTracker`, was observed but not featured because no personal contribution details were supplied for it.

Collaborator access alone does not make a repository appear as one you own or create authored commits. GitHub's pinning rules require ownership or qualifying recent contributions. If a teammate committed your frontend work under their identity, discuss accurate attribution with them; do not manufacture commit history.

## Changes made

- Published a profile README with selected projects, stack information and attributed frontend contributions.
- Added complete mobile source, real-screen fixture screenshots, a data/model card, USB demo instructions, engineering checks and APK downloads to NutriCare.
- Added a factual root README and `.env.example` to the MERN application and replaced its currently committed database URL with `MONGODB_URI` configuration.
- Added NutriCare repository topics and a concise description. The API did not permit editing account-level name/bio fields, so those existing fields were left unchanged.

## Owner action still required

**Rotate the previously exposed MongoDB credential in the MERN project.** The current source no longer contains it, but it remains in older public commits. Removing a string is not a revocation. Update the private backend environment after rotating it. No credential value is repeated in this document.

Optional presentation cleanup: use the profile's **Customize your pins** to feature NutriCare, SplitKaro, the MERN application, Smart Mart and the two collaborator projects (where eligible). Existing coursework was not deleted, hidden or renamed. Smart Mart currently includes generated build/distribution folders; consider cleaning those in a separate, reviewed maintenance change.

Suggested bio, if accurate: “Full-stack development with React, FastAPI, PostgreSQL and Flutter. Building APIs, database-backed apps and mobile demos.”

## Interview talking points to prepare

Explain the real request path from Flutter/React through the API and database; identify your own work; demonstrate login and a persistent record change; explain token/cache ownership, error handling and one automated test. For NutriCare, be explicit that medication-aware rules surround a baseline classifier and clinical validation is pending. For team projects, describe your frontend contribution rather than taking credit for the whole backend.

Primary profile guidance: https://docs.github.com/en/account-and-profile/how-tos/profile-customization/pinning-items-to-your-profile and https://docs.github.com/en/account-and-profile/reference/profile-reference
