<script>
import { GlButton, GlTable } from '@gitlab/ui';
import { __ } from '~/locale';

const i18n = {
  cloudRun: __('Cloud Run'),
  cloudRunDescription: __('Deploy container based web apps on Google managed clusters'),
  cloudStorage: __('Cloud Storage'),
  cloudStorageDescription: __('Deploy static assets and resources to Google managed CDN'),
  deployments: __('Deployments'),
  deploymentsDescription: __(
    'Configure pipelines to deploy web apps, backend services, APIs and static resources to Google Cloud',
  ),
  configureViaMergeRequest: __('Configure via Merge Request'),
  service: __('Service'),
  description: __('Description'),
};

export default {
  components: { GlButton, GlTable },
  props: {
    cloudRunUrl: {
      type: String,
      required: true,
    },
    cloudStorageUrl: {
      type: String,
      required: true,
    },
  },
  fields: [
    { key: 'title', label: i18n.service },
    { key: 'description', label: i18n.description },
    { key: 'action', label: '' },
  ],
  items: [
    {
      title: i18n.cloudRun,
      description: i18n.cloudRunDescription,
      action: { title: i18n.configureViaMergeRequest, disabled: true },
    },
    {
      title: i18n.cloudStorage,
      description: i18n.cloudStorageDescription,
      action: { title: i18n.configureViaMergeRequest, disabled: true },
    },
  ],
  i18n,
};
</script>
<template>
  <div class="gl-mx-3">
    <h2 class="gl-font-size-h2">{{ $options.i18n.deployments }}</h2>
    <p>{{ $options.i18n.deploymentsDescription }}</p>
    <gl-table :fields="$options.fields" :items="$options.items">
      <template #cell(action)="{ value }">
        <gl-button :disabled="value.disabled">{{ value.title }}</gl-button>
      </template>
    </gl-table>
  </div>
</template>
