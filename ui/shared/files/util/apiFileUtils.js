// Copyright (C) 2017 - present Instructure, Inc.
//
// This file is part of Canvas.
//
// Canvas is free software: you can redistribute it and/or modify it under
// the terms of the GNU Affero General Public License as published by the Free
// Software Foundation, version 3 of the License.
//
// Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
// details.
//
// You should have received a copy of the GNU Affero General Public License along
// with this program. If not, see <http://www.gnu.org/licenses/>.

import axios from '@canvas/axios'

const stringIds = {Accept: 'application/json+canvas-string-ids'}

export function getRootFolder(contextType, contextId) {
  return axios.get(`/api/v1/${contextType}/${contextId}/folders/root`, stringIds)
}

function createFormData(data) {
  const formData = new FormData()
  Object.keys(data).forEach(key => formData.append(key, data[key]))
  return formData
}

// Frative: axios (@canvas/axios) attaches global default headers (Accept,
// X-Requested-With) to every request, including cross-origin ones. Some
// S3-compatible storage CORS policies (e.g. a Cloudflare R2 bucket only
// allowing the `content-type` header) reject the PUT because of those extra
// headers, even with a valid presigned URL — the browser blocks it before
// it reaches R2. Raw XHR sends only the header we explicitly set.
//
// Also, unlike the classic S3 presigned-POST flow (which auto-redirects to
// success_url as part of the POST response, transparently followed by
// axios — no separate JS step needed), a PUT has no such mechanism, so we
// have to ping success_url ourselves once the upload completes. See
// notes/canvas-fork-estrategia.md in frative-docs.
function presignedPutUpload(url, file, successUrl, bucket, key) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('PUT', url)
    xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream')
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        if (successUrl) {
          const qs = new URLSearchParams({bucket, key})
          const sep = successUrl.includes('?') ? '&' : '?'
          axios
            .get(successUrl + sep + qs.toString())
            .then(response => resolve(response))
            .catch(reject)
        } else {
          resolve({data: {}})
        }
      } else {
        reject(new Error(`Upload failed with status ${xhr.status}`))
      }
    }
    xhr.onerror = () => reject(new Error('Network Error'))
    xhr.send(file)
  })
}

function onFileUploadInfoReceived(file, uploadInfo, onSuccess, onFailure) {
  const params = uploadInfo.upload_params || {}
  const upload =
    params.upload_method === 'PUT'
      ? presignedPutUpload(uploadInfo.upload_url, file, params.success_url, params.bucket, params.key)
      : axios.post(uploadInfo.upload_url, createFormData({...params, file}), {
          'Content-Type': 'multipart/form-data',
          ...stringIds,
        })

  upload.then(response => onSuccess(response.data)).catch(response => onFailure(response))
}

export function uploadFile(file, folderId, onSuccess, onFailure) {
  axios
    .post(
      `/api/v1/folders/${folderId}/files`,
      {
        name: file.name,
        size: file.size,
        parent_folder_id: folderId,
        on_duplicate: 'rename',
      },
      stringIds,
    )
    .then(response => onFileUploadInfoReceived(file, response.data, onSuccess, onFailure))
    .catch(response => onFailure(response))
}
