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

function onFileUploadInfoReceived(file, uploadInfo, onSuccess, onFailure) {
  // Frative: some S3-compatible backends (e.g. Cloudflare R2) only support
  // presigned PUT, not presigned POST — the preflight already returns a
  // fully-signed upload_url in that case. upload_method travels inside
  // upload_params, not as a top-level field — the server-side JSON is
  // sliced down to upload_url/upload_params/file_param only. See
  // notes/canvas-fork-estrategia.md in frative-docs.
  const upload =
    uploadInfo.upload_params?.upload_method === 'PUT'
      ? axios.put(uploadInfo.upload_url, file, {
          headers: {'Content-Type': file.type || 'application/octet-stream', ...stringIds},
        })
      : axios.post(uploadInfo.upload_url, createFormData({...uploadInfo.upload_params, file}), {
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
