<script>
import { GlButton, GlSprintf, GlLink, GlSafeHtmlDirective } from '@gitlab/ui';
import emptyStateSVG from 'icons/_mr_widget_empty_state.svg';
import api from '~/api';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'MRWidgetNothingToMerge',
  components: {
    GlButton,
    GlSprintf,
    GlLink,
  },
  directives: {
    SafeHtml: GlSafeHtmlDirective,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return { emptyStateSVG };
  },
  methods: {
    onClickNewFile() {
      api.trackRedisHllUserEvent('i_code_review_widget_nothing_merge_click_new_file');
    },
  },
  ciHelpPage: helpPagePath('/ci/quick_start/index.html'),
  safeHtmlConfig: { ADD_TAGS: ['use'] },
};
</script>

<template>
  <div class="mr-widget-body mr-widget-empty-state">
    <div class="row">
      <div
        class="artwork col-md-5 order-md-last col-12 text-center d-flex justify-content-center align-items-center"
      >
        <span v-safe-html:[$options.safeHtmlConfig]="emptyStateSVG"></span>
      </div>
      <div class="text col-md-7 order-md-first col-12">
        <p class="highlight">
          {{ s__('mrWidgetNothingToMerge|This merge request contains no changes.') }}
        </p>
        <p>
          <gl-sprintf
            :message="
              s__(
                'mrWidgetNothingToMerge|Use merge requests to propose changes to your project and discuss them with your team. To make changes, push a commit or edit this merge request to use a different branch. With %{linkStart}CI/CD%{linkEnd}, automatically test your changes before merging.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.ciHelpPage" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
        <div>
          <gl-button
            v-if="mr.newBlobPath"
            :href="mr.newBlobPath"
            category="primary"
            variant="confirm"
            data-testid="createFileButton"
            @click="onClickNewFile"
          >
            {{ __('Create file') }}
          </gl-button>
        </div>
      </div>
    </div>
  </div>
</template>
