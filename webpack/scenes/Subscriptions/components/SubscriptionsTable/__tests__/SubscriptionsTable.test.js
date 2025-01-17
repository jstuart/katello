import React from 'react';
import { render, mount } from 'enzyme';
import toJson from 'enzyme-to-json';
import { MemoryRouter } from 'react-router-dom';
import SubscriptionsTable from '../SubscriptionsTable';
import { successState, loadingState, emptyState } from '../../../__tests__/subscriptions.fixtures';
import { loadSubscriptions, updateQuantity } from '../../../SubscriptionActions';

jest.mock('foremanReact/components/Pagination/PaginationWrapper');
jest.useFakeTimers();

const tableColumns = [
  'id',
  'product_id',
  'contract_number',
  'start_date',
  'end_date',
];
describe('subscriptions table', () => {
  it('should render a table', async () => {
    // Wrapping SubscriptionTable in MemoryRouter here since it contains
    // a Link componenent, which can't be used outside a Router
    /* eslint-disable react/jsx-indent */

    const page = render(<MemoryRouter>
          <SubscriptionsTable
            subscriptions={successState}
            loadSubscriptions={loadSubscriptions}
            tableColumns={tableColumns}
            updateQuantity={updateQuantity}
            subscriptionDeleteModalOpen={false}
            onSubscriptionDeleteModalClose={() => { }}
            onDeleteSubscriptions={() => {}}
            toggleDeleteButton={() => {}}
            emptyState={{}}
          />
                        </MemoryRouter>);
    expect(toJson(page)).toMatchSnapshot();
  });

  it('should disable checkboxes for custom subscriptions', async () => {
    /* eslint-disable react/jsx-indent */
    const page = render(<MemoryRouter>
      <SubscriptionsTable
        subscriptions={successState}
        loadSubscriptions={loadSubscriptions}
        tableColumns={tableColumns}
        updateQuantity={updateQuantity}
        subscriptionDeleteModalOpen={false}
        onSubscriptionDeleteModalClose={() => { }}
        onDeleteSubscriptions={() => {}}
        toggleDeleteButton={() => {}}
        emptyState={{}}
      />
                        </MemoryRouter>);
    expect(page.find('#select1').is('[disabled]')).toBe(true);
  });

  it('should render an empty state', async () => {
    const emptyStateData = {
      header: __('Yay empty state'),
      description: __('There is nothing to see here'),
    };

    /* eslint-disable react/jsx-indent */
    const page = render(<MemoryRouter>
      <SubscriptionsTable
        subscriptions={emptyState}
        emptyState={emptyStateData}
        loadSubscriptions={loadSubscriptions}
        updateQuantity={updateQuantity}
        subscriptionDeleteModalOpen={false}
        onSubscriptionDeleteModalClose={() => {}}
        onDeleteSubscriptions={() => {}}
        toggleDeleteButton={() => {}}
        tableColumns={[]}
      />
                        </MemoryRouter>);
    expect(toJson(page)).toMatchSnapshot();
  });
  /* eslint-enable react/jsx-indent */

  it('should render a loading state', async () => {
    const page = mount(<SubscriptionsTable
      subscriptions={loadingState}
      loadSubscriptions={loadSubscriptions}
      tableColumns={tableColumns}
      updateQuantity={updateQuantity}
      subscriptionDeleteModalOpen={false}
      onSubscriptionDeleteModalClose={() => { }}
      onDeleteSubscriptions={() => {}}
      toggleDeleteButton={() => {}}
      emptyState={{}}
    />);
    jest.runAllTimers();
    page.update();
    expect(toJson(page)).toMatchSnapshot();
  });
});
