import React from 'react';
import PropTypes from 'prop-types';
import { Col, ListView } from 'patternfly-react';
import SubscriptionDetailProduct from './SubscriptionDetailProduct';

const SubscriptionDetailProductContent = ({ productContent }) => {
  const listItems = productContent.results.map(product => ({
    index: product.id,
    title: product.name,
    availableContent: (
      product.available_content.map(c => (
        {
          enabled: c.enabled,
          ...c.content,
        }
      ))
    ),
  }));

  if (listItems.length > 0) {
    return (
      <ListView>
        {listItems.map(({
              index,
              title,
              availableContent,
            }) => (
              <ListView.Item
                key={index}
                heading={title}
                hideCloseIcon
              >

                <Col sm={12}>
                  {availableContent.map(content => (
                    <SubscriptionDetailProduct key={content.id} content={content} />
                  ))}
                </Col>
              </ListView.Item>
        ))}
      </ListView>
    );
  }

  return (
    <div>{ __('No products are enabled.') }</div>
  );
};

SubscriptionDetailProductContent.propTypes = {
  productContent: PropTypes.shape({
    results: PropTypes.array,
  }).isRequired,
};

export default SubscriptionDetailProductContent;
