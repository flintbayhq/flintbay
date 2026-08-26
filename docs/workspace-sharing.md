# Workspace Sharing

Flintbay supports multi-user collaboration. Invite team members to your workspace and assign roles that control what they can do.

## Roles

| Role | Can View | Can Operate | Can Edit | Can Admin |
|------|----------|-------------|----------|-----------|
| **viewer** | ✅ | — | — | — |
| **operator** | ✅ | ✅ | — | — |
| **editor** | ✅ | ✅ | ✅ | — |
| **admin** | ✅ | ✅ | ✅ | ✅ |

### What Each Level Means

- **View** — See dashboards, screens, pages, widgets
- **Operate** — Interact with control widgets (press buttons, move sliders, toggle switches), and
  observe the connections behind them: connection logs, source health, failures, warnings, and the
  values an endpoint has recently delivered
- **Edit** — Create/modify/delete screens, pages, widgets, sources, endpoints, bindings, and read
  the workspace's audit trail: who created, changed or deleted what
- **Admin** — Manage workspace settings, invite/remove members, change roles, clear the connection log

Observing a connection and configuring it are separate: an operator can see that a source is
down, with its latency and last error, but cannot read its configuration — which is where the
broker credentials and authorization headers live.

None of the four covers accounts or API keys. Creating accounts, resetting
passwords and minting personal access tokens sit on the deployment axis, not on a
workspace role — see [Security](security.md#deployment-administrators).

## Inviting Members

1. Sidebar → **Workspace** panel → click the members icon
2. Click **Invite Member**
3. Search for the user by username
4. Select a role
5. Click **Add**

The user must already have a Flintbay account. They'll see the workspace in their workspace selector immediately.

> **Tip:** Use the `operator` role for people who only need to press buttons and monitor — they can't accidentally break your dashboard configuration.

> **The other way in:** the deployment administrator can also place an account into
> any workspace from **Sidebar → Administration → Users → Workspace access**, without being a member
> of that workspace first. It is the same table and the same four roles; what differs
> is that the workspace's own admin invites *into their workspace*, while the
> deployment administrator can do it across all of them. Both are recorded in the
> audit trail.

## Changing Roles

1. Open the members dialog
2. Click the role dropdown next to the member
3. Select the new role
4. Change takes effect immediately

## Removing Members

1. Open the members dialog
2. Click the remove button next to the member
3. Confirm removal

The user loses access immediately. Their sessions for this workspace are not terminated, but any new request will be denied.

## Workspace Isolation

Each workspace is fully isolated:
- Members of workspace A cannot see workspace B's data
- Screens, sources, bindings, and widgets belong to exactly one workspace
- Audit logs are workspace-scoped
- API keys operate within the user's workspace context

## Who Can Manage Members

Only users with the **admin** role in a workspace can:
- Invite new members
- Remove existing members
- Change member roles

The workspace creator is automatically an admin.

## Limits

- No limit on members per workspace
- A user can be a member of multiple workspaces
- Each user has one role per workspace (not cumulative)
