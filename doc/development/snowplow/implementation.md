---
stage: Growth
group: Product Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Implement Snowplow tracking

This page describes how to:

- Implement Snowplow frontend and backend tracking
- Test Snowplow events

## Snowplow JavaScript frontend tracking

GitLab provides a `Tracking` interface that wraps the [Snowplow JavaScript tracker](https://docs.snowplowanalytics.com/docs/collecting-data/collecting-from-own-applications/javascript-trackers/)
to track custom events.

For the recommended frontend tracking implementation, see [Usage recommendations](#usage-recommendations).

Tracking implementations must have an `action` and a `category`. You can provide additional
categories from the [structured event taxonomy](index.md#structured-event-taxonomy) with an `extra` object
that accepts key-value pairs.

| Field      | Type   | Default value              | Description                                                                                                                                                                                                    |
|:-----------|:-------|:---------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `category` | string | `document.body.dataset.page` | Page or subsection of a page in which events are captured.                                                                                                                                            |
| `action`   | string | generic                  | Action the user is taking. Clicks must be `click` and activations must be `activate`. For example, focusing a form field is `activate_form_input`, and clicking a button is `click_button`. |
| `data`     | object | `{}`                         | Additional data such as `label`, `property`, `value`, `context` as described in [Structured event taxonomy](index.md#structured-event-taxonomy), and `extra` (key-value pairs object). |

### Usage recommendations

- Use [data attributes](#implement-data-attribute-tracking) on HTML elements that emit `click`, `show.bs.dropdown`, or `hide.bs.dropdown` events.
- Use the [Vue mixin](#implement-vue-component-tracking) for tracking custom events, or if the supported events for data attributes are not propagating.
- Use the [tracking class](#implement-raw-javascript-tracking) when tracking raw JavaScript files.

### Implement data attribute tracking

To implement tracking for HAML or Vue templates, add a [`data-track` attribute](#data-track-attributes) to the element.

The following example shows `data-track-*` attributes assigned to a button:

```haml
%button.btn{ data: { track: { action: "click_button", label: "template_preview", property: "my-template" } } }
```

```html
<button class="btn"
  data-track-action="click_button"
  data-track-label="template_preview"
  data-track-property="my-template"
  data-track-extra='{ "template_variant": "primary" }'
/>
```

#### `data-track` attributes

| Attribute             | Required | Description |
|:----------------------|:---------|:------------|
| `data-track-action`    | true     | Action the user is taking. Clicks must be prepended with `click` and activations must be prepended with `activate`. For example, focusing a form field is `activate_form_input` and clicking a button is `click_button`. Replaces `data-track-event`, which was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/290962) in GitLab 13.11. |
| `data-track-label`    | false    | The specific element or object to act on. This can be: the label of the element, for example, a tab labeled 'Create from template' for `create_from_template`; a unique identifier if no text is available, for example, `groups_dropdown_close` for closing the Groups dropdown in the top bar; or the name or title attribute of a record being created. |
| `data-track-property` | false    | Any additional property of the element, or object being acted on. |
| `data-track-value`    | false    | Describes a numeric value (decimal) directly related to the event. This could be the value of an input. For example, `10` when clicking `internal` visibility. If omitted, this is the element's `value` property or `undefined`. For checkboxes, the default value is the element's checked attribute or `0` when unchecked. |
| `data-track-extra` | false    | A key-value pair object passed as a valid JSON string. This attribute is added to the `extra` property in our [`gitlab_standard`](schemas.md#gitlab_standard) schema. |
| `data-track-context`  | false    | The `context` as described in our [Structured event taxonomy](index.md#structured-event-taxonomy). |

#### Event listeners

Event listeners bind at the document level to handle click events in elements with data attributes.
This allows them to be handled when the DOM re-renders or changes. Document-level binding reduces
the likelihood that click events stop propagating up the DOM tree.

If click events stop propagating, you must implement listeners and [Vue component tracking](#implement-vue-component-tracking) or [raw JavaScript tracking](#implement-raw-javascript-tracking).

#### Helper methods

Use the following Ruby helper:

```ruby
tracking_attrs(label, action, property) # { data: { track_label... } }

%button{ **tracking_attrs('main_navigation', 'click_button', 'navigation') }
```

If you use the GitLab helper method [`nav_link`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/helpers/tab_helper.rb#L76), you must wrap `html_options` under the `html_options` keyword argument. If you
use the `ActionView` helper method [`link_to`](https://api.rubyonrails.org/v5.2.3/classes/ActionView/Helpers/UrlHelper.html#method-i-link_to), you don't need to wrap `html_options`.

```ruby
# Bad
= nav_link(controller: ['dashboard/groups', 'explore/groups'], data: { track_label: "explore_groups",
track_action: "click_button" })

# Good
= nav_link(controller: ['dashboard/groups', 'explore/groups'], html_options: { data: { track_label: 
"explore_groups", track_action: "click_button" } })

# Good (other helpers)
= link_to explore_groups_path, title: _("Explore"), data: { track_label: "explore_groups", track_action:
"click_button" }
```

### Implement Vue component tracking

For custom event tracking, use a Vue `mixin` in components. Vue `mixin` exposes the `Tracking.event`
static method and the `track` method. You can specify tracking options in `data` or `computed`.
These options override any defaults and allow the values to be dynamic from props or based on state.

Several default options are passed when an event is tracked from the component:

- `category`: If you don't specify, by default `document.body.dataset.page` is used.
- `label`
- `property`
- `value`

To implement Vue component tracking:

1. Import the `Tracking` library and request a `mixin`:

    ```javascript
    import Tracking from '~/tracking';
    const trackingMixin = Tracking.mixin;
    ```

1. Provide categories to track the event from the component. For example, to track all events in a
component with a label, use the `label` category:

    ```javascript
    import Tracking from '~/tracking';
    const trackingMixin = Tracking.mixin({ label: 'right_sidebar' });
    ```

1. In the component, declare the Vue `mixin`:

    ```javascript
    export default {
      mixins: [trackingMixin],
      // ...[component implementation]...
      data() {
        return {
          expanded: false,
          tracking: {
            label: 'left_sidebar',
          },
        };
      },
    };
    ```

1. To receive event data as a tracking object or computed property:
   - Declare it in the `data` function. Use a `tracking` object when default event properties are dynamic or provided at runtime:

      ```javascript
      export default {
        name: 'RightSidebar',
        mixins: [Tracking.mixin()],
        data() {
          return {
            tracking: {
              label: 'right_sidebar',
              // category: '',
              // property: '',
              // value: '',
              // experiment: '',
              // extra: {},
            },
          };
        },
      };
      ```

   - Declare it in the event data in the `track` function. This object merges with any previously provided options:

      ```javascript
      this.track('click_button', {
        label: 'right_sidebar',
      });
      ```

1. Optional. Use the `track` method in a template:

    ```html
    <template>
      <div>
        <button data-testid="toggle" @click="toggle">Toggle</button>

        <div v-if="expanded">
          <p>Hello world!</p>
          <button @click="track('click_action')">Track another event</button>
        </div>
      </div>
    </template>
    ```

The following example shows an implementation of Vue component tracking:

```javascript
export default {
  name: 'RightSidebar',
  mixins: [Tracking.mixin({ label: 'right_sidebar' })],
  data() {
    return {
      expanded: false,
    };
  },
  methods: {
    toggle() {
      this.expanded = !this.expanded;
      // Additional data will be merged, like `value` below
      this.track('click_toggle', { value: Number(this.expanded) });
    }
  }
};
```

#### Testing example

```javascript
import { mockTracking } from 'helpers/tracking_helper';
// mockTracking(category, documentOverride, spyMethod)

describe('RightSidebar.vue', () => {
  let trackingSpy;
  let wrapper;

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
  });

  const findToggle = () => wrapper.find('[data-testid="toggle"]');

  it('tracks turning off toggle', () => {
    findToggle().trigger('click');

    expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_toggle', {
      label: 'right_sidebar',
      value: 0,
    });
  });
});
```

### Implement raw JavaScript tracking

To call custom event tracking and instrumentation directly from the JavaScript file, call the `Tracking.event` static function.

The following example demonstrates tracking a click on a button by manually calling `Tracking.event`.

```javascript
import Tracking from '~/tracking';

const button = document.getElementById('create_from_template_button');

button.addEventListener('click', () => {
  Tracking.event('dashboard:projects:index', 'click_button', {
    label: 'create_from_template',
    property: 'template_preview',
    extra: {
      templateVariant: 'primary',
      valid: 1,
    },
  });
});
```

#### Testing example

```javascript
import Tracking from '~/tracking';

describe('MyTracking', () => {
  let wrapper;

  beforeEach(() => {
    jest.spyOn(Tracking, 'event');
  });

  const findButton = () => wrapper.find('[data-testid="create_from_template"]');

  it('tracks event', () => {
    findButton().trigger('click');

    expect(Tracking.event).toHaveBeenCalledWith(undefined, 'click_button', {
      label: 'create_from_template',
      property: 'template_preview',
      extra: {
        templateVariant: 'primary',
        valid: true,
      },
    });
  });
});
```

### Form tracking

To enable Snowplow automatic [form tracking](https://docs.snowplowanalytics.com/docs/collecting-data/collecting-from-own-applications/javascript-trackers/javascript-tracker/javascript-tracker-v2/tracking-specific-events/#form-tracking):

1. Call `Tracking.enableFormTracking` when the DOM is ready.
1. Provide a `config` object that includes at least one of the following elements:
    - `forms` determines the forms to track. Identified by the CSS class name.
    - `fields` determines the fields inside the tracked forms to track. Identified by the field `name`.
1. Optional. Provide a list of contexts as the second argument. The [`gitlab_standard`](schemas.md#gitlab_standard) schema is excluded from these events.

```javascript
Tracking.enableFormTracking({
  forms: { allow: ['sign-in-form', 'password-recovery-form'] },
  fields: { allow: ['terms_and_conditions', 'newsletter_agreement'] },
});
```

#### Testing example

```javascript
import Tracking from '~/tracking';

describe('MyFormTracking', () => {
  let formTrackingSpy;

  beforeEach(() => {
    formTrackingSpy = jest
      .spyOn(Tracking, 'enableFormTracking')
      .mockImplementation(() => null);
  });

  it('initialized with the correct configuration', () => {
    expect(formTrackingSpy).toHaveBeenCalledWith({
      forms: { allow: ['sign-in-form', 'password-recovery-form'] },
      fields: { allow: ['terms_and_conditions', 'newsletter_agreement'] },
    });
  });
});
```

## Implement Ruby backend tracking

`Gitlab::Tracking` is an interface that wraps the [Snowplow Ruby Tracker](https://docs.snowplowanalytics.com/docs/collecting-data/collecting-from-own-applications/ruby-tracker/) for tracking custom events.
Backend tracking provides:

- User behavior tracking
- Instrumentation to monitor and visualize performance over time in a section or aspect of code.

To add custom event tracking and instrumentation, call the `GitLab::Tracking.event` class method.
For example:

```ruby
class Projects::CreateService < BaseService
  def execute
    project = Project.create(params)

    Gitlab::Tracking.event('Projects::CreateService', 'create_project', label: project.errors.full_messages.to_sentence,
                           property: project.valid?.to_s, project: project, user: current_user, namespace: namespace)
  end
end
```

Use the following arguments:

| Argument   | Type                      | Default value | Description                                                                                                                       |
|------------|---------------------------|---------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `category` | String                    |               | Area or aspect of the application. For example,  `HealthCheckController` or `Lfs::FileTransformer`.                  |
| `action`   | String                    |               | The action being taken. For example, a controller action such as `create`, or an Active Record callback. |
| `label`    | String                    | nil           | The specific element or object to act on. This can be one of the following: the label of the element, for example, a tab labeled 'Create from template' for `create_from_template`; a unique identifier if no text is available, for example, `groups_dropdown_close` for closing the Groups dropdown in the top bar; or the name or title attribute of a record being created.                                                          |
| `property` | String                    | nil           | Any additional property of the element, or object being acted on.                                                          |
| `value`    | Numeric                   | nil           | Describes a numeric value (decimal) directly related to the event. This could be the value of an input. For example, `10` when clicking `internal` visibility.                                                          |
| `context`  | Array\[SelfDescribingJSON\] | nil           | An array of custom contexts to send with this event. Most events should not have any custom contexts.                             |
| `project`  | Project                   | nil           | The project associated with the event. |
| `user`     | User                      | nil           | The user associated with the event. |
| `namespace` | Namespace                | nil           | The namespace associated with the event. |
| `extra`   | Hash                | `{}`         | Additional keyword arguments are collected into a hash and sent with the event. |

### Unit testing

To test backend Snowplow events, use the `expect_snowplow_event` helper. For more information, see
[testing best practices](../testing_guide/best_practices.md#test-snowplow-events).

### Performance

We use the [AsyncEmitter](https://docs.snowplowanalytics.com/docs/collecting-data/collecting-from-own-applications/ruby-tracker/emitters/#the-asyncemitter-class) when tracking events, which allows for instrumentation calls to be run in a background thread. This is still an active area of development.

## Develop and test Snowplow

To develop and test a Snowplow event, there are several tools to test frontend and backend events:

| Testing Tool                                 | Frontend Tracking  | Backend Tracking    | Local Development Environment | Production Environment | Production Environment |
|----------------------------------------------|--------------------|---------------------|-------------------------------|------------------------|------------------------|
| Snowplow Analytics Debugger Chrome Extension | Yes | No | Yes            | Yes     | Yes     |
| Snowplow Inspector Chrome Extension          | Yes | No | Yes            | Yes     | Yes     |
| Snowplow Micro                               | Yes | Yes  | Yes            | No    | No    |

### Test frontend events

Before you test frontend events in development, you must:

1. [Enable Snowplow tracking in the Admin Area](index.md#enable-snowplow-tracking).
1. Turn off ad blockers that could prevent Snowplow JavaScript from loading in your environment.
1. Turn off "Do Not Track" (DNT) in your browser.

All URLs are pseudonymized. The entity identifier [replaces](https://docs.snowplowanalytics.com/docs/collecting-data/collecting-from-own-applications/javascript-trackers/javascript-tracker/javascript-tracker-v2/tracker-setup/other-parameters-2/#Setting_a_custom_page_URL_and_referrer_URL) personally identifiable
information (PII). PII includes usernames, group, and project names.
Page titles are hardcoded as `GitLab` for the same reason.

#### Snowplow Analytics Debugger Chrome Extension

[Snowplow Analytics Debugger](https://www.iglooanalytics.com/blog/snowplow-analytics-debugger-chrome-extension.html) is a browser extension for testing frontend events. It works in production, staging, and local development environments.

1. Install the [Snowplow Analytics Debugger](https://chrome.google.com/webstore/detail/snowplow-analytics-debugg/jbnlcgeengmijcghameodeaenefieedm) Chrome browser extension.
1. Open Chrome DevTools to the Snowplow Analytics Debugger tab.

#### Snowplow Inspector Chrome Extension

Snowplow Inspector Chrome Extension is a browser extension for testing frontend events. This works in production, staging, and local development environments.

1. Install [Snowplow Inspector](https://chrome.google.com/webstore/detail/snowplow-inspector/maplkdomeamdlngconidoefjpogkmljm?hl=en).
1. To open the extension, select the Snowplow Inspector icon beside the address bar.
1. Click around on a webpage with Snowplow to see JavaScript events firing in the inspector window.

### Test backend events

#### Snowplow Micro

[Snowplow Micro](https://snowplowanalytics.com/blog/2019/07/17/introducing-snowplow-micro/) is a
Docker-based solution for testing backend and frontend in a local development environment. Snowplow Micro
records the same events as the full Snowplow pipeline. To query events, use the Snowplow Micro API.

It can be set up automatically using [GitLab Development Kit (GDK)](https://gitlab.com/gitlab-org/gitlab-development-kit).
See the [how-to docs](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/snowplow_micro.md) for more details.

Optionally, you can set it up manually, using the following instructions.

#### Set up Snowplow Micro manually

To install and run Snowplow Micro, complete these steps to modify the
[GitLab Development Kit (GDK)](https://gitlab.com/gitlab-org/gitlab-development-kit):

1. Ensure [Docker is installed](https://docs.docker.com/get-docker/) and running.

1. To install Snowplow Micro, clone the settings in
[this project](https://gitlab.com/gitlab-org/snowplow-micro-configuration).

1. Navigate to the directory with the cloned project,
   and start the appropriate Docker container:

   ```shell
   ./snowplow-micro.sh
   ```

1. Set the environment variable to tell the GDK to use Snowplow Micro in development. This overrides two `application_settings` options:
   - `snowplow_enabled` setting will instead return `true` from `Gitlab::Tracking.enabled?`
   - `snowplow_collector_hostname` setting will instead always return `localhost:9090` (or whatever is set for `SNOWPLOW_MICRO_URI`) from `Gitlab::Tracking.collector_hostname`.

   ```shell
   export SNOWPLOW_MICRO_ENABLE=1
   ```

   Optionally, you can set the URI for you Snowplow Micro instance as well (the default value is `http://localhost:9090`):

   ```shell
   export SNOWPLOW_MICRO_URI=https://127.0.0.1:8080
   ```

1. Restart GDK:

   ```shell
   gdk restart
   ```

1. Send a test Snowplow event from the Rails console:

   ```ruby
   Gitlab::Tracking.event('category', 'action')
   ```

1. Navigate to `localhost:9090/micro/good` to see the event.

#### Useful links

- [Snowplow Micro repository](https://github.com/snowplow-incubator/snowplow-micro)
- [Installation guide recording](https://www.youtube.com/watch?v=OX46fo_A0Ag)

### Troubleshoot

To control content security policy warnings when using an external host, modify `config/gitlab.yml`
to allow or disallow them. To allow them, add the relevant host for `connect_src`. For example, for
`https://snowplow.trx.gitlab.net`:

```yaml
development:
  <<: *base
  gitlab:
    content_security_policy:
      enabled: true
      directives:
        connect_src: "'self' http://localhost:* http://127.0.0.1:* ws://localhost:* wss://localhost:* ws://127.0.0.1:* https://snowplow.trx.gitlab.net/"
```
